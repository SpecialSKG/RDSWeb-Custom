# =====================================================================
# Configuración del Sitio IIS — Portal RD Web
# Llamado por el instalador de Inno Setup — NO ejecutar manualmente
# =====================================================================
param(
    [Parameter(Mandatory)][string]$SiteName,
    [Parameter(Mandatory)][string]$FrontendDir,
    [Parameter(Mandatory)][string]$CertThumbprint,
    [Parameter(Mandatory)][string]$LogFile,
    [int]$HttpsPort  = 443,
    [int]$BackendPort = 3000
)

$ErrorActionPreference = "Stop"
Start-Transcript -Path $LogFile -Force

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
    Write-Host "Configurando HTTPS en puerto $HttpsPort..."
    New-WebBinding -Name $SiteName `
                   -Protocol "https" `
                   -Port $HttpsPort `
                   -IPAddress "*"

    # Asignar certificado al binding
    $Binding = Get-WebBinding -Name $SiteName -Protocol "https"
    $Binding.AddSslCertificate($CertThumbprint, "My")
    Write-Host "Certificado SSL asignado correctamente."

    # ── 6. Agregar binding HTTP (redirect a HTTPS) ───────────────────
    New-WebBinding -Name $SiteName `
                   -Protocol "http" `
                   -Port 80 `
                   -IPAddress "*"
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
            Write-Host "Intento $i/$MaxRetries — esperando a que IIS registre el sitio..."
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

    Stop-Transcript
    exit 0
}
catch {
    Write-Host "ERROR: $($_.Exception.Message)"
    Stop-Transcript
    exit 1
}
