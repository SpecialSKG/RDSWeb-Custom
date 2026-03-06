# =====================================================================
# Instalador Maestro Todo-en-Uno: Portal RD Web (Backend + Frontend)
# =====================================================================
$ErrorActionPreference = "Stop"

# 1. VERIFICACIÓN DE PRIVILEGIOS
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[ERROR] Este script requiere permisos de Administrador." -ForegroundColor Red
    Write-Host "Haz clic derecho en el archivo -> 'Ejecutar con PowerShell' (o ábrelo como administrador)." -ForegroundColor Yellow
    Read-Host "Presiona Enter para salir..."
    Exit
}

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host " Iniciando Instalación Completa: Portal RD Web" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

# 2. DEFINICIÓN DE RUTAS ESTRUCTURADAS
$SourceDir = $PSScriptRoot
$SourceBackend = "$SourceDir\backend"
$SourceFrontend = "$SourceDir\frontend"

# Puedes ajustar estas rutas destino si en tu IIS se llaman diferente
$TargetBackend = "C:\inetpub\wwwroot\backend"
$TargetFrontend = "C:\inetpub\wwwroot\frontend"

$ServiceName = "RDSWeb"
$NssmTarget = "$TargetBackend\nssm.exe"
$AppEntry = "$TargetBackend\src\index.js"

# node.exe se incluye dentro del paquete backend (no requiere instalación global)
$NodePathSource = "$SourceBackend\node.exe"
$NodePath       = "$TargetBackend\node.exe"

# 3. PRE-FLIGHT CHECKS (Validación del ZIP)
if (-not (Test-Path $NodePathSource)) {
    Write-Host "[ERROR] No se encontró node.exe en el paquete ($NodePathSource)." -ForegroundColor Red
    Read-Host "Asegúrate de que el ZIP fue generado correctamente con build.ps1..."
    Exit
}
if (-not (Test-Path $SourceBackend) -or -not (Test-Path $SourceFrontend)) {
    Write-Host "[ERROR] Estructura de archivos incorrecta." -ForegroundColor Red
    Write-Host "El script espera encontrar las carpetas 'backend' y 'frontend' junto a este archivo." -ForegroundColor Yellow
    Read-Host "Presiona Enter para salir..."
    Exit
}

# =====================================================================
# FASE 0: INSTALACIÓN DE PRERREQUISITOS DE IIS (URL Rewrite & ARR)
# =====================================================================
Write-Host "`n[FASE 0] Verificando Prerrequisitos de IIS..." -ForegroundColor Cyan

$PrereqsDir = "$SourceDir\prereqs"
$RewriteDll = "$env:windir\System32\inetsrv\rewrite.dll"
$ArrDll = "$env:windir\System32\inetsrv\requestRouter.dll"
$AppCmd = "$env:windir\System32\inetsrv\appcmd.exe"

# 1. Instalar URL Rewrite
if (-not (Test-Path $RewriteDll)) {
    Write-Host "  -> Instalando IIS URL Rewrite 2.1 silenciosamente..." -ForegroundColor Yellow
    $RewriteMsi = "$PrereqsDir\rewrite_amd64_es-ES.msi"
    if (-not (Test-Path $RewriteMsi)) {
        Write-Host "[ERROR] No se encontró el instalador: $RewriteMsi" -ForegroundColor Red
        Read-Host "Presiona Enter para salir..."
        Exit
    }
    $p = Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$RewriteMsi`" /qn /norestart" -Wait -NoNewWindow -PassThru
    if ($p.ExitCode -notin @(0, 3010)) {
        Write-Host "[ERROR] Falló la instalación de URL Rewrite (exit code $($p.ExitCode))." -ForegroundColor Red
        Read-Host "Presiona Enter para salir..."
        Exit
    }
    Write-Host "  -> URL Rewrite instalado correctamente." -ForegroundColor Green
}
else {
    Write-Host "  -> URL Rewrite ya está instalado." -ForegroundColor Green
}

# 2. Instalar ARR 3.0
if (-not (Test-Path $ArrDll)) {
    Write-Host "  -> Instalando IIS Application Request Routing (ARR) silenciosamente..." -ForegroundColor Yellow
    $ArrMsi = "$PrereqsDir\requestRouter_amd64.msi"
    if (-not (Test-Path $ArrMsi)) {
        Write-Host "[ERROR] No se encontró el instalador: $ArrMsi" -ForegroundColor Red
        Read-Host "Presiona Enter para salir..."
        Exit
    }
    $p = Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$ArrMsi`" /qn /norestart" -Wait -NoNewWindow -PassThru
    if ($p.ExitCode -notin @(0, 3010)) {
        Write-Host "[ERROR] Falló la instalación de ARR (exit code $($p.ExitCode))." -ForegroundColor Red
        Read-Host "Presiona Enter para salir..."
        Exit
    }
    Write-Host "  -> ARR 3.0 instalado correctamente." -ForegroundColor Green
}
else {
    Write-Host "  -> ARR 3.0 ya está instalado." -ForegroundColor Green
}

# 3. Activar el Proxy Inverso a nivel de Servidor (CRÍTICO)
# Aunque ARR se instale, la función de Proxy Inverso viene apagada por defecto.
if (Test-Path $AppCmd) {
    Write-Host "  -> Asegurando que la función de Proxy Inverso esté habilitada en IIS..."
    & $AppCmd set config -section:system.webServer/proxy /enabled:"True" /commit:apphost | Out-Null
}

# 4. Reiniciar IIS para que cargue los módulos recién instalados
Write-Host "  -> Reiniciando IIS para aplicar cambios..." -ForegroundColor Yellow
& iisreset /noforce | Out-Null
Write-Host "  -> IIS reiniciado." -ForegroundColor Green

# 4. CREDENCIALES (Para el Backend)
Write-Host "`n[FASE 1] Configuración de Credenciales" -ForegroundColor Cyan
Write-Host "El backend necesita una cuenta del dominio (Ej: LAB-MH\usr_admin) para consultar RDS." -ForegroundColor Yellow

do {
    $ServiceUser = Read-Host "Usuario del dominio (formato: DOMINIO\\usuario)"
    if ($ServiceUser -notmatch '\\|@') {
        Write-Host "  [!] Debes incluir el dominio. Ejemplo: LAB-MH\\usr_admin" -ForegroundColor Red
    }
} while ($ServiceUser -notmatch '\\|@')

$SecurePass = Read-Host "Contraseña" -AsSecureString

$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePass)
$PlainPass = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)


# =====================================================================
# FASE 2: DESPLIEGUE DEL BACKEND (EXPRESS)
# =====================================================================
Write-Host "`n[FASE 2] Desplegando Backend..." -ForegroundColor Cyan

# 2.1 Detener y eliminar servicio previo (reinstalación limpia)
if (Get-Service -Name $ServiceName -ErrorAction SilentlyContinue) {
    Write-Host "  -> Servicio '$ServiceName' existente detectado. Eliminando..." -ForegroundColor Yellow
    try {
        Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2

        # Usar nssm del destino si existe, si no, usar el de la fuente (fallo parcial previo)
        $NssmForRemoval = if (Test-Path $NssmTarget) { $NssmTarget } else { "$SourceBackend\nssm.exe" }

        & $NssmForRemoval remove $ServiceName confirm
        if ($LASTEXITCODE -ne 0) {
            throw "nssm remove falló (exit code $LASTEXITCODE). El servicio puede seguir registrado."
        }
        Start-Sleep -Seconds 1
        Write-Host "  -> Servicio anterior eliminado correctamente." -ForegroundColor Green
    }
    catch {
        Write-Host "[ERROR] No se pudo eliminar el servicio existente: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Ejecuta manualmente: sc delete $ServiceName" -ForegroundColor Yellow
        Exit
    }
}

# 2.2 Copiar archivos del backend
try {
    if (-not (Test-Path $TargetBackend)) { New-Item -ItemType Directory -Force -Path $TargetBackend | Out-Null }
    Write-Host "  -> Copiando archivos del backend a $TargetBackend..."
    Copy-Item -Path "$SourceBackend\*" -Destination $TargetBackend -Recurse -Force -ErrorAction Stop
}
catch {
    Write-Host "[ERROR] Falló la copia del backend. Verifica que ningún archivo esté en uso." -ForegroundColor Red
    Exit
}

# 2.3 Instalar Servicio de Windows
try {
    # Helper: ejecuta nssm y aborta si falla
    function Invoke-Nssm {
        param([string[]]$NssmArgs)
        & $NssmTarget @NssmArgs
        if ($LASTEXITCODE -ne 0) {
            throw "NSSM falló en: nssm $($NssmArgs -join ' ') (exit code $LASTEXITCODE)"
        }
    }

    Write-Host "  -> Instalando servicio persistente ($ServiceName)..."
    Invoke-Nssm @('install', $ServiceName, $NodePath, "`"$AppEntry`"")
    Invoke-Nssm @('set', $ServiceName, 'AppDirectory', $TargetBackend)
    Invoke-Nssm @('set', $ServiceName, 'AppEnvironmentExtra', 'NODE_ENV=production')
    Invoke-Nssm @('set', $ServiceName, 'ObjectName', $ServiceUser, $PlainPass)

    # Configurar logs (stdout + stderr → archivos, rotación cada 5 MB)
    $LogDir = "$TargetBackend\logs"
    if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Force -Path $LogDir | Out-Null }
    Invoke-Nssm @('set', $ServiceName, 'AppStdout',       "$LogDir\backend-out.log")
    Invoke-Nssm @('set', $ServiceName, 'AppStderr',       "$LogDir\backend-error.log")
    Invoke-Nssm @('set', $ServiceName, 'AppRotateFiles',  '1')
    Invoke-Nssm @('set', $ServiceName, 'AppRotateOnline', '1')
    Invoke-Nssm @('set', $ServiceName, 'AppRotateBytes',  '5242880')

    Start-Service -Name $ServiceName -ErrorAction Stop
    Write-Host "  -> Backend en línea y conectado al Active Directory." -ForegroundColor Green
}
catch {
    Write-Host "[ERROR] Falló la instalación del servicio: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  -> Limpiando servicio incompleto..." -ForegroundColor Yellow
    if (Get-Service -Name $ServiceName -ErrorAction SilentlyContinue) {
        Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
        & $NssmTarget remove $ServiceName confirm 2>$null
    }
    Write-Host "Verifica el usuario/contraseña e intenta de nuevo." -ForegroundColor Yellow
    Exit
}

# =====================================================================
# FASE 3: DESPLIEGUE DEL FRONTEND (Angular en IIS)
# =====================================================================
Write-Host "`n[FASE 3] Desplegando Frontend (Angular)..." -ForegroundColor Cyan

try {
    if (-not (Test-Path $TargetFrontend)) {
        Write-Host "  -> Creando directorio de IIS en $TargetFrontend..."
        New-Item -ItemType Directory -Force -Path $TargetFrontend | Out-Null
    }

    Write-Host "  -> Copiando archivos compilados de Angular..."
    Copy-Item -Path "$SourceFrontend\*" -Destination $TargetFrontend -Recurse -Force -ErrorAction Stop
    Write-Host "  -> Frontend actualizado con éxito." -ForegroundColor Green
}
catch {
    Write-Host "[ERROR] Falló la copia del frontend." -ForegroundColor Red
    Write-Host "Detalle: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Asegúrate de que el IIS no tenga bloqueados los archivos estáticos." -ForegroundColor Yellow
}

# =====================================================================
# FINALIZACIÓN
# =====================================================================
Write-Host "`n========================================================" -ForegroundColor Green
Write-Host " ¡INSTALACIÓN COMPLETADA CON ÉXITO!" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
Write-Host "RECORDATORIOS PARA INFRAESTRUCTURA:"
Write-Host "1. Validar que la carpeta de Angular ($TargetFrontend) esté apuntada correctamente en el IIS."
Write-Host "2. Copia el archivo .env con la configuración real a: $TargetBackend\.env"
Write-Host "3. Verifica que IIS tenga habilitado el Proxy Inverso (FASE 0 lo hace automáticamente)."
Write-Host ""
Read-Host "Presiona Enter para cerrar esta ventana..."