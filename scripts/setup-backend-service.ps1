# =====================================================================
# Instalación del Servicio Backend (NSSM)
# Llamado por el instalador de Inno Setup — NO ejecutar manualmente
# =====================================================================
param(
    [Parameter(Mandatory)][string]$BackendDir,
    [Parameter(Mandatory)][string]$ServiceName,
    [Parameter(Mandatory)][string]$PasswordFile,
    [Parameter(Mandatory)][string]$LogFile
)

$ErrorActionPreference = "Stop"
Start-Transcript -Path $LogFile -Force

try {
    # ── Leer y eliminar archivo de contraseña ────────────────────────
    if (-not (Test-Path $PasswordFile)) {
        throw "No se encontró el archivo de credenciales: $PasswordFile"
    }
    $PlainPass = (Get-Content -Path $PasswordFile -Raw).Trim()
    Remove-Item $PasswordFile -Force -ErrorAction SilentlyContinue

    # ── Resolución de rutas ──────────────────────────────────────────
    $ServiceUser = "$env:USERDOMAIN\$env:USERNAME"
    $NssmExe     = "$BackendDir\nssm.exe"
    $NodeExe     = "$BackendDir\node.exe"
    $AppEntry    = "$BackendDir\src\index.js"
    $LogDir      = "$BackendDir\logs"

    if (-not (Test-Path $NssmExe))  { throw "nssm.exe no encontrado en: $NssmExe" }
    if (-not (Test-Path $NodeExe))  { throw "node.exe no encontrado en: $NodeExe" }
    if (-not (Test-Path $AppEntry)) { throw "index.js no encontrado en: $AppEntry" }

    # ── Helper: ejecutar nssm y abortar si falla ─────────────────────
    function Invoke-Nssm {
        param([string[]]$NssmArgs)
        & $NssmExe @NssmArgs
        if ($LASTEXITCODE -ne 0) {
            throw "NSSM falló: nssm $($NssmArgs -join ' ') (exit code $LASTEXITCODE)"
        }
    }

    # ── 1. Validar credenciales contra Active Directory ──────────────
    Write-Host "Validando credenciales de $ServiceUser contra Active Directory..."
    try {
        Add-Type -AssemblyName System.DirectoryServices.AccountManagement
        $ctx = New-Object System.DirectoryServices.AccountManagement.PrincipalContext(
            [System.DirectoryServices.AccountManagement.ContextType]::Domain,
            $env:USERDNSDOMAIN
        )
        if (-not $ctx.ValidateCredentials($env:USERNAME, $PlainPass)) {
            throw "La contraseña proporcionada no es válida para $ServiceUser."
        }
        Write-Host "Credenciales verificadas correctamente."
    }
    catch [System.DirectoryServices.AccountManagement.PrincipalException] {
        Write-Host "[ADVERTENCIA] No se pudo verificar contra el dominio: $($_.Exception.Message)"
        Write-Host "Continuando — el error se detectará al iniciar el servicio."
    }

    # ── 2. Eliminar servicio anterior si existe ──────────────────────
    if (Get-Service -Name $ServiceName -ErrorAction SilentlyContinue) {
        Write-Host "Eliminando servicio anterior '$ServiceName'..."
        Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        Invoke-Nssm @('remove', $ServiceName, 'confirm')
        Start-Sleep -Seconds 1
        Write-Host "Servicio anterior eliminado."
    }

    # ── 3. Instalar nuevo servicio ───────────────────────────────────
    Write-Host "Instalando servicio '$ServiceName'..."
    Invoke-Nssm @('install', $ServiceName, $NodeExe, "`"$AppEntry`"")
    Invoke-Nssm @('set', $ServiceName, 'AppDirectory',       $BackendDir)
    Invoke-Nssm @('set', $ServiceName, 'AppEnvironmentExtra', 'NODE_ENV=production')
    Invoke-Nssm @('set', $ServiceName, 'ObjectName',         $ServiceUser, $PlainPass)

    # ── 4. Configurar logging (stdout + stderr, rotación 5 MB) ──────
    if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Force -Path $LogDir | Out-Null }
    Invoke-Nssm @('set', $ServiceName, 'AppStdout',       "$LogDir\backend-out.log")
    Invoke-Nssm @('set', $ServiceName, 'AppStderr',       "$LogDir\backend-error.log")
    Invoke-Nssm @('set', $ServiceName, 'AppRotateFiles',  '1')
    Invoke-Nssm @('set', $ServiceName, 'AppRotateOnline', '1')
    Invoke-Nssm @('set', $ServiceName, 'AppRotateBytes',  '5242880')

    # ── 5. Iniciar servicio ──────────────────────────────────────────
    Write-Host "Iniciando servicio..."
    Start-Service -Name $ServiceName -ErrorAction Stop
    Write-Host "Servicio '$ServiceName' en línea y conectado al Active Directory."

    # ── Limpieza de memoria ──────────────────────────────────────────
    $PlainPass = $null
    [System.GC]::Collect()

    Stop-Transcript
    exit 0
}
catch {
    Write-Host "ERROR: $($_.Exception.Message)"
    $PlainPass = $null

    # Limpiar servicio incompleto si quedó registrado
    if (Get-Service -Name $ServiceName -ErrorAction SilentlyContinue) {
        Write-Host "Limpiando servicio incompleto..."
        Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
        $NssmExe = "$BackendDir\nssm.exe"
        if (Test-Path $NssmExe) {
            & $NssmExe remove $ServiceName confirm 2>$null
        }
    }

    Stop-Transcript
    exit 1
}
