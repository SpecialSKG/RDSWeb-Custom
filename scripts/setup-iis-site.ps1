# =====================================================================
# Configuración del Sitio IIS — Portal RD Web
# Llamado por el instalador de Inno Setup — NO ejecutar manualmente
# =====================================================================
param(
    [Parameter(Mandatory)][string]$SiteName,
    [Parameter(Mandatory)][string]$FrontendDir,
    [Parameter(Mandatory)][string]$CertThumbprint,
    [Parameter(Mandatory)][string]$LogFile,
    [string]$HostName = '',
    [int]$HttpsPort  = 443,
    [int]$BackendPort = 3000
)

$ErrorActionPreference = "Stop"

# ── Asegurar que el directorio del log existe ────────────────────────
$LogDir = Split-Path -Parent $LogFile
if ($LogDir -and -not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

# ── Iniciar transcript (con fallback) ────────────────────────────────
$TranscriptStarted = $false
try {
    Start-Transcript -Path $LogFile -Force
    $TranscriptStarted = $true
} catch {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Error al iniciar transcript: $($_.Exception.Message)" |
        Out-File $LogFile -Force -ErrorAction SilentlyContinue
}

# ── Diagnóstico de parámetros recibidos ──────────────────────────────
Write-Host "=== Configuracion Sitio IIS - Diagnostico ==="
Write-Host "  PowerShell:     $($PSVersionTable.PSVersion)"
Write-Host "  64-bit:         $([Environment]::Is64BitProcess)"
Write-Host "  SiteName:       $SiteName"
Write-Host "  FrontendDir:    $FrontendDir"
Write-Host "  CertThumbprint: $CertThumbprint"
Write-Host "  LogFile:        $LogFile"
Write-Host "  HostName:       $HostName"
Write-Host "  HttpsPort:      $HttpsPort"
Write-Host "  BackendPort:    $BackendPort"
Write-Host ""

try {
    Import-Module WebAdministration -ErrorAction Stop

    # ── 1. Detener y eliminar sitio anterior si existe ───────────────
    if (Get-Website -Name $SiteName -ErrorAction SilentlyContinue) {
        Write-Host "Deteniendo sitio IIS existente '$SiteName'..."
        Stop-Website -Name $SiteName -ErrorAction SilentlyContinue
        Write-Host "Eliminando sitio IIS existente '$SiteName'..."
        Remove-Website -Name $SiteName
        Start-Sleep -Seconds 1
    }

    # ── 2. Detener Default Web Site si ocupa el puerto ───────────────
    $DefaultSite = Get-Website -Name "Default Web Site" -ErrorAction SilentlyContinue
    if ($DefaultSite -and $DefaultSite.State -eq 'Started') {
        $Bindings = Get-WebBinding -Name "Default Web Site" -ErrorAction SilentlyContinue
        $Conflict = $Bindings | Where-Object { $_.bindingInformation -match ":${HttpsPort}:" }
        if ($Conflict) {
            Write-Host "Deteniendo 'Default Web Site' (conflicto en puerto $HttpsPort)..."
            Stop-Website -Name "Default Web Site" -ErrorAction SilentlyContinue
        }
    }

    # ── 3. Validar certificado ───────────────────────────────────────
    $Cert = Get-ChildItem "Cert:\LocalMachine\My\$CertThumbprint" -ErrorAction Stop
    Write-Host "Certificado encontrado: $($Cert.Subject) (expira: $($Cert.NotAfter.ToString('yyyy-MM-dd')))"

    # ── 4. Crear nuevo sitio IIS ─────────────────────────────────────
    Write-Host "Creando sitio '$SiteName' en: $FrontendDir"
    New-Website -Name $SiteName `
                -PhysicalPath $FrontendDir `
                -Force | Out-Null

    # Eliminar bindings por defecto (HTTP :80) creados automáticamente
    Get-WebBinding -Name $SiteName | Remove-WebBinding

    # ── 5. Agregar binding HTTPS con certificado ─────────────────────
    Write-Host "Configurando HTTPS en puerto $HttpsPort (host: $HostName)..."
    if ($HostName -ne '') {
        New-WebBinding -Name $SiteName `
                       -Protocol "https" `
                       -Port $HttpsPort `
                       -HostHeader $HostName `
                       -SslFlags 1 `
                       -IPAddress "*"
    } else {
        New-WebBinding -Name $SiteName `
                       -Protocol "https" `
                       -Port $HttpsPort `
                       -IPAddress "*"
    }

    # Asignar certificado al binding
    $Binding = Get-WebBinding -Name $SiteName -Protocol "https"
    $Binding.AddSslCertificate($CertThumbprint, "My")
    Write-Host "Certificado SSL asignado correctamente."

    # ── 6. Agregar binding HTTP (redirect a HTTPS) ───────────────────
    if ($HostName -ne '') {
        New-WebBinding -Name $SiteName `
                       -Protocol "http" `
                       -Port 80 `
                       -HostHeader $HostName `
                       -IPAddress "*"
    } else {
        New-WebBinding -Name $SiteName `
                       -Protocol "http" `
                       -Port 80 `
                       -IPAddress "*"
    }
    Write-Host "Binding HTTP :80 agregado (redireccion a HTTPS via web.config)."

    # ── 7. Configurar Application Pool ───────────────────────────────
    $PoolName = $SiteName -replace '[^a-zA-Z0-9]', ''
    $PoolName = "${PoolName}Pool"

    if (-not (Test-Path "IIS:\AppPools\$PoolName")) {
        New-WebAppPool -Name $PoolName | Out-Null
    }
    Set-ItemProperty "IIS:\AppPools\$PoolName" -Name "managedRuntimeVersion" -Value ""
    Set-ItemProperty "IIS:\AppPools\$PoolName" -Name "processModel.identityType" -Value "ApplicationPoolIdentity"
    Set-ItemProperty "IIS:\Sites\$SiteName" -Name "applicationPool" -Value $PoolName
    Write-Host "Application Pool '$PoolName' configurado (No Managed Code)."

    # ── 8. Iniciar el sitio (reintentar — IIS puede tardar en registrar el objeto) ─
    $MaxRetries = 3
    for ($i = 1; $i -le $MaxRetries; $i++) {
        try {
            Start-Sleep -Seconds 2
            Start-Website -Name $SiteName
            Write-Host "Sitio '$SiteName' iniciado correctamente."
            break
        }
        catch {
            Write-Host "Intento $i/$MaxRetries - esperando a que IIS registre el sitio..."
            if ($i -eq $MaxRetries) {
                Write-Host "ADVERTENCIA: No se pudo iniciar el sitio automaticamente. IIS lo iniciara al recibir la primera peticion."
            }
        }
    }

    Write-Host ""
    Write-Host "=== Configuracion IIS completada ==="
    Write-Host "  Sitio:        $SiteName"
    Write-Host "  Ruta fisica:  $FrontendDir"
    Write-Host "  HTTPS:        https://localhost:$HttpsPort"
    Write-Host "  Reverse Proxy: /api/* -> http://localhost:$BackendPort/api/*"
    Write-Host "  (El reverse proxy se configura via web.config del frontend)"
    Write-Host ""

    if ($TranscriptStarted) { Stop-Transcript }
    exit 0
}
catch {
    $errText = $_.Exception.Message
    $errStack = $_.ScriptStackTrace
    Write-Host "ERROR: $errText"
    Write-Host "STACK: $errStack"
    if ($TranscriptStarted) { Stop-Transcript }
    # Escribir error al log aunque transcript haya fallado
    $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    "$ts - ERROR: $errText" | Out-File $LogFile -Append -ErrorAction SilentlyContinue
    "STACK: $errStack" | Out-File $LogFile -Append -ErrorAction SilentlyContinue
    exit 1
}
