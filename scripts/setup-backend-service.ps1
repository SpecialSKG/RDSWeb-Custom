<#
.SYNOPSIS
    Instala y configura el Servicio Backend (NSSM) para el Portal RDS Web.

.DESCRIPTION
    Este script automatiza la instalación de un servicio backend (Node.js o Python) 
    utilizando NSSM. Configura el entorno de ejecución, establece políticas de 
    rotación de logs y gestiona la limpieza de archivos sensibles.
    
    Diseñado para ser invocado por Inno Setup o flujos de CI/CD. No ejecutar manualmente
    sin los parámetros adecuados.

.PARAMETER BackendDir
    Directorio raíz donde se encuentran los binarios del backend y NSSM.

.PARAMETER ServiceName
    Nombre del servicio de Windows a crear.

.PARAMETER CredentialFile
    Ruta al archivo temporal que contiene la contraseña en texto plano. Se eliminará tras su lectura.

.PARAMETER LogFile
    Ruta para almacenar el transcript de la ejecución del script.

.PARAMETER BackendType
    Tipo de backend a instalar ('express' o 'python'). Por defecto es 'express'.

.PARAMETER ServiceUser
    Cuenta de servicio a utilizar. Puede ser formato UPN o DOMINIO\Usuario.

.PARAMETER ServiceDomain
    Nombre NetBIOS del dominio. Si no se provee, se intentará autodetectar.

.EXAMPLE
    .\setup-backend-service.ps1 -BackendDir "C:\App\Backend" -ServiceName "RDSBackend" -CredentialFile "C:\temp\creds.txt" -LogFile "C:\logs\install.log"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path $_ -PathType Container })]
    [string]$BackendDir,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ServiceName,

    [Parameter(Mandatory = $true)]
    [System.IO.FileInfo]$CredentialFile,

    [Parameter(Mandatory = $true)]
    [string]$LogFile,

    [ValidateSet('express', 'python')]
    [string]$BackendType = 'express',

    [Parameter(Mandatory = $true)]
    [string]$ServiceUser,

    [Parameter(Mandatory = $true)]
    [string]$ServiceDomain
)

$ErrorActionPreference = 'Stop'
$WarningPreference = 'Continue'
$InformationPreference = 'Continue'

# =====================================================================
# Funciones Auxiliares (Helpers)
# =====================================================================

function Invoke-NssmCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$NssmPath,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )
    
    $safeArgsToLog = if ($Arguments -contains 'ObjectName') { "[Argumentos ocultos por seguridad]" } else { $Arguments -join ' ' }
    Write-Verbose "Ejecutando NSSM: $NssmPath $safeArgsToLog"
    
    & $NssmPath @Arguments
    
    if ($LASTEXITCODE -ne 0) {
        throw "NSSM falló con código de salida $LASTEXITCODE. Comando: nssm $safeArgsToLog"
    }
}

# =====================================================================
# Flujo Principal
# =====================================================================

Start-Transcript -Path $LogFile -Force -Append:$false | Out-Null
Write-Information "Iniciando instalación del servicio backend: $ServiceName"

try {
    # ── 1. Gestión Segura de Credenciales ────────────────────────────
    if (-not $CredentialFile.Exists) {
        throw "Archivo de credenciales no encontrado en la ruta: $($CredentialFile.FullName)"
    }
    
    # Extraemos la contraseña en texto plano para NSSM
    $tempPlainTextPass = (Get-Content -Path $CredentialFile.FullName -Raw).Trim()
    
    # Destruimos el archivo inmediatamente por seguridad
    Remove-Item -Path $CredentialFile.FullName -Force -ErrorAction SilentlyContinue
    Write-Verbose "Archivo temporal de credenciales eliminado exitosamente."

    # ── 2. Resolución de Rutas y Entorno ─────────────────────────────
    $nssmExe = Join-Path -Path $BackendDir -ChildPath "nssm.exe"
    $logDir = Join-Path -Path $BackendDir -ChildPath "logs"

    if ($BackendType -eq 'python') {
        $mainExe = Join-Path -Path $BackendDir -ChildPath "main.exe"
        $appPath = $mainExe
        $appArgs = ""
        # Inyectamos PYTHONUTF8=1 usando un salto de línea (`n) para NSSM
        $envExtra = "PYTHONUNBUFFERED=1`nPYTHONUTF8=1"
    } else {
        $nodeExe = Join-Path -Path $BackendDir -ChildPath "node.exe"
        $appEntry = Join-Path -Path $BackendDir -ChildPath "src\index.js"
        $appPath = $nodeExe
        $appArgs = "`"$appEntry`""
        $envExtra = "NODE_ENV=production"
    }

    # ── 3. Limpieza de Servicio Previo ───────────────────────────────
    if (Get-Service -Name $ServiceName -ErrorAction SilentlyContinue) {
        Write-Information "Deteniendo y eliminando servicio existente..."
        Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        Invoke-NssmCommand -NssmPath $nssmExe -Arguments @('remove', $ServiceName, 'confirm')
    }

    # ── 4. Instalación y Configuración del Nuevo Servicio ────────────
    Write-Information "Instalando servicio '$ServiceName' con backend '$BackendType'..."
    
    # NSIS nos pasa el Dominio y el Usuario por separado, los concatenamos para NSSM
    $nssmAccountName = "$ServiceDomain\$ServiceUser"

    $nssmConfigurations = @(
        @('install', $ServiceName, $appPath, $appArgs),
        @('set', $ServiceName, 'AppDirectory', $BackendDir),
        @('set', $ServiceName, 'AppEnvironmentExtra', $envExtra),
        @('set', $ServiceName, 'ObjectName', $nssmAccountName, $tempPlainTextPass),
        @('set', $ServiceName, 'DisplayName', 'Portal RDS Web'),
        @('set', $ServiceName, 'Description', 'Servicio backend del Portal RDS Web.')
    )

    foreach ($configArgs in $nssmConfigurations) {
        $validArgs = $configArgs | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        Invoke-NssmCommand -NssmPath $nssmExe -Arguments $validArgs
    }
    
    # Limpiamos la variable de la memoria
    $tempPlainTextPass = $null

    # ── 5. Configuración de Logs (Rotación) ──────────────────────────
    if (-not (Test-Path -Path $logDir)) { 
        New-Item -ItemType Directory -Force -Path $logDir | Out-Null 
    }

    $logConfigurations = @(
        @('set', $ServiceName, 'AppStdout', "$logDir\backend-out.log"),
        @('set', $ServiceName, 'AppStderr', "$logDir\backend-error.log"),
        @('set', $ServiceName, 'AppRotateFiles', '1'),
        @('set', $ServiceName, 'AppRotateOnline', '1'),
        @('set', $ServiceName, 'AppRotateSeconds', '86400'),
        @('set', $ServiceName, 'AppRotateBytes', '10485760')
    )

    foreach ($logArgs in $logConfigurations) { 
        Invoke-NssmCommand -NssmPath $nssmExe -Arguments $logArgs 
    }

    # ── 6. Arranque del Servicio ─────────────────────────────────────
    Start-Service -Name $ServiceName
    Write-Information "Servicio '$ServiceName' configurado e iniciado exitosamente bajo la cuenta $nssmAccountName."
}
catch {
    Write-Error "Fallo crítico en la instalación: $($_.Exception.Message)"
    Stop-Transcript | Out-Null
    exit 1
}
finally {
    # ── 7. Limpieza Segura Final ─────────────────────────────────────
    $tempPlainTextPass = $null
}

Stop-Transcript | Out-Null
exit 0