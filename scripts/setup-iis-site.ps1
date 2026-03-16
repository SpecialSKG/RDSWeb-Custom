<#
.SYNOPSIS
    Configura el Sitio IIS, Bindings y Application Pool para el Portal RDS Web.

.DESCRIPTION
    Este script automatiza la provisión de un sitio web en IIS. Se encarga de limpiar 
    instalaciones previas, resolver conflictos de puertos (ej. Default Web Site), 
    asignar certificados SSL, configurar el Application Pool sin código administrado 
    (ideal para frontends SPA) y establecer los bindings HTTP/HTTPS.

.PARAMETER SiteName
    Nombre del sitio web y base para el nombre del Application Pool.

.PARAMETER FrontendDir
    Ruta física donde residen los archivos estáticos del frontend.

.PARAMETER CertThumbprint
    Huella digital (Thumbprint) del certificado SSL preinstalado en LocalMachine\My.

.PARAMETER LogFile
    Ruta absoluta para el archivo de log (Transcript).

.PARAMETER HostName
    (Opcional) Host header / FQDN del sitio. Ej: portal.midominio.com.

.PARAMETER HttpsPort
    (Opcional) Puerto para el tráfico HTTPS. Por defecto: 443.

.PARAMETER BackendPort
    (Opcional) Puerto donde escucha el backend (solo para documentación/logs). Por defecto: 3000.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$SiteName,

    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path $_ -PathType Container })]
    [string]$FrontendDir,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[a-fA-F0-9]{40}$')]
    [string]$CertThumbprint,

    [Parameter(Mandatory = $true)]
    [string]$LogFile,

    [string]$HostName = '',
    
    [ValidateRange(1, 65535)]
    [int]$HttpsPort = 443,
    
    [ValidateRange(1, 65535)]
    [int]$BackendPort = 3000
)

$ErrorActionPreference = 'Stop'
$WarningPreference = 'Continue'
$InformationPreference = 'Continue'

# =====================================================================
# Funciones Auxiliares
# =====================================================================

function Wait-IisSiteStart {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [int]$MaxRetries = 3,
        [int]$DelaySeconds = 2
    )

    for ($i = 1; $i -le $MaxRetries; $i++) {
        try {
            Start-Sleep -Seconds $DelaySeconds
            Start-Website -Name $Name -ErrorAction Stop
            Write-Information "Sitio '$Name' iniciado correctamente en el intento $i."
            return
        }
        catch {
            # FIX: Delimitamos la variable con ${} para separarla de los dos puntos
            Write-Warning "Intento $i/${MaxRetries}: Esperando a que el proveedor IIS registre el objeto..."
            
            if ($i -eq $MaxRetries) {
                Write-Warning "No se pudo iniciar el sitio automáticamente. IIS lo iniciará al recibir la primera petición externa."
            }
        }
    }
}

# =====================================================================
# Inicialización y Logs
# =====================================================================

$logDir = Split-Path -Parent $LogFile
if (-not [string]::IsNullOrWhiteSpace($logDir) -and -not (Test-Path -Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

Start-Transcript -Path $LogFile -Force -Append:$false | Out-Null

Write-Information "=== Configuración Sitio IIS - Diagnóstico ==="
Write-Information "  SiteName:       $SiteName"
Write-Information "  FrontendDir:    $FrontendDir"
Write-Information "  CertThumbprint: $CertThumbprint"
Write-Information "  HostName:       $(if ($HostName) { $HostName } else { '* (Any)' })"
Write-Information "  Puertos:        HTTPS:$HttpsPort | Backend:$BackendPort"
Write-Information "============================================"

try {
    # ── 0. Cargar Módulo IIS ─────────────────────────────────────────
    Import-Module WebAdministration -ErrorAction Stop

    # ── 1. Limpieza Idempotente (Sitio y AppPool) ────────────────────
    if (Get-Website -Name $SiteName -ErrorAction SilentlyContinue) {
        Write-Information "Limpiando sitio IIS existente '$SiteName'..."
        Stop-Website -Name $SiteName -ErrorAction SilentlyContinue
        Remove-Website -Name $SiteName -ErrorAction Stop
        Start-Sleep -Seconds 1
    }

    $poolName = ($SiteName -replace '[^a-zA-Z0-9]', '') + 'Pool'
    if (Test-Path -Path "IIS:\AppPools\$poolName") {
        Write-Information "Limpiando Application Pool existente '$poolName'..."
        Remove-WebAppPool -Name $poolName -ErrorAction Stop
    }

    # ── 2. Resolución de Conflictos (Default Web Site) ───────────────
    $defaultSite = Get-Website -Name "Default Web Site" -ErrorAction SilentlyContinue
    if ($defaultSite -and $defaultSite.State -eq 'Started') {
        $conflict = Get-WebBinding -Name "Default Web Site" -ErrorAction SilentlyContinue | 
        Where-Object { $_.bindingInformation -match ":${HttpsPort}:" }
        
        if ($conflict) {
            Write-Warning "Se detectó conflicto en puerto $HttpsPort con 'Default Web Site'. Deteniendo sitio por defecto..."
            Stop-Website -Name "Default Web Site" -ErrorAction Stop
        }
    }

    # ── 3. Validación de Certificado SSL ─────────────────────────────
    Write-Information "Validando certificado SSL ($CertThumbprint)..."
    $certPath = "Cert:\LocalMachine\My\$CertThumbprint"
    if (-not (Test-Path -Path $certPath)) {
        throw "No se encontró el certificado con huella $CertThumbprint en LocalMachine\My."
    }
    $cert = Get-Item -Path $certPath
    Write-Information "Certificado encontrado: $($cert.Subject) (Expira: $($cert.NotAfter.ToString('yyyy-MM-dd')))"

    # ── 4. Configurar Application Pool ───────────────────────────────
    Write-Information "Creando Application Pool '$poolName' (No Managed Code)..."
    New-WebAppPool -Name $poolName | Out-Null
    Set-ItemProperty -Path "IIS:\AppPools\$poolName" -Name "managedRuntimeVersion" -Value ""
    Set-ItemProperty -Path "IIS:\AppPools\$poolName" -Name "processModel.identityType" -Value "ApplicationPoolIdentity"

    # ── 5. Crear Sitio IIS ───────────────────────────────────────────
    Write-Information "Creando sitio '$SiteName' vinculado a '$poolName'..."
    New-Website -Name $SiteName -PhysicalPath $FrontendDir -ApplicationPool $poolName -Force | Out-Null

    Get-WebBinding -Name $SiteName | Remove-WebBinding

    # ── 6. Configurar Bindings (HTTPS y HTTP Redirect) ───────────────
    Write-Information "Configurando bindings de red..."

    $bindingParamsHttps = @{
        Name      = $SiteName
        Protocol  = 'https'
        Port      = $HttpsPort
        IPAddress = '*'
    }
    $bindingParamsHttp = @{
        Name      = $SiteName
        Protocol  = 'http'
        Port      = 80
        IPAddress = '*'
    }

    if (-not [string]::IsNullOrWhiteSpace($HostName)) {
        $bindingParamsHttps.Add('HostHeader', $HostName)
        $bindingParamsHttps.Add('SslFlags', 1)
        $bindingParamsHttp.Add('HostHeader', $HostName)
    }

    New-WebBinding @bindingParamsHttps
    $httpsBinding = Get-WebBinding -Name $SiteName -Protocol 'https'
    $httpsBinding.AddSslCertificate($CertThumbprint, "My")
    Write-Information "Binding HTTPS configurado y certificado asignado exitosamente."

    New-WebBinding @bindingParamsHttp
    Write-Information "Binding HTTP (Puerto 80) configurado para redirección."

    # ── 7. Arranque del Sitio ────────────────────────────────────────
    Wait-IisSiteStart -Name $SiteName

    Write-Information "=== Configuración de IIS Completada ==="
    
    # FIX: Reemplazo del operador ternario por un bloque if/else seguro para PS 5.1
    $displayHost = if ([string]::IsNullOrWhiteSpace($HostName)) { 'localhost' } else { $HostName }
    Write-Information " Sitio operativo en: https://${displayHost}:$HttpsPort"

}
catch {
    Write-Error "Fallo crítico en la configuración del sitio IIS: $($_.Exception.Message)"
    Write-Verbose "Stack Trace:`n$($_.ScriptStackTrace)"
    Stop-Transcript | Out-Null
    exit 1
}

Stop-Transcript | Out-Null
exit 0