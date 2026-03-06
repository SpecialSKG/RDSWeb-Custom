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
$TargetBackend  = "C:\inetpub\wwwroot\backend"
$TargetFrontend = "C:\inetpub\wwwroot\frontend"

$ServiceName = "RDSWeb"
$NssmTarget = "$TargetBackend\nssm.exe"
$AppEntry = "$TargetBackend\src\index.js"

$NodePath = (Get-Command "node.exe" -ErrorAction SilentlyContinue).Source

# 3. PRE-FLIGHT CHECKS (Validación del ZIP)
if (-not $NodePath) {
    Write-Host "[ERROR] Node.js no está instalado o no está en el PATH de Windows." -ForegroundColor Red
    Read-Host "Instala Node.js en este servidor y vuelve a intentarlo..."
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
$ArrDll     = "$env:windir\System32\inetsrv\requestRouter.dll"
$AppCmd     = "$env:windir\System32\inetsrv\appcmd.exe"

# 1. Instalar URL Rewrite
if (-not (Test-Path $RewriteDll)) {
    Write-Host "  -> Instalando IIS URL Rewrite 2.1 silenciosamente..." -ForegroundColor Yellow
    $RewriteMsi = "$PrereqsDir\rewrite_amd64.msi"
    Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$RewriteMsi`" /qn /norestart" -Wait -NoNewWindow
} else {
    Write-Host "  -> URL Rewrite ya está instalado." -ForegroundColor Green
}

# 2. Instalar ARR 3.0
if (-not (Test-Path $ArrDll)) {
    Write-Host "  -> Instalando IIS Application Request Routing (ARR) silenciosamente..." -ForegroundColor Yellow
    $ArrMsi = "$PrereqsDir\requestRouter_amd64.msi"
    Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$ArrMsi`" /qn /norestart" -Wait -NoNewWindow
} else {
    Write-Host "  -> ARR 3.0 ya está instalado." -ForegroundColor Green
}

# 3. Activar el Proxy Inverso a nivel de Servidor (CRÍTICO)
# Aunque ARR se instale, la función de Proxy Inverso viene apagada por defecto.
if (Test-Path $AppCmd) {
    Write-Host "  -> Asegurando que la función de Proxy Inverso esté habilitada en IIS..."
    & $AppCmd set config -section:system.webServer/proxy /enabled:"True" /commit:apphost | Out-Null
}

# 4. CREDENCIALES (Para el Backend)
Write-Host "`n[FASE 1] Configuración de Credenciales" -ForegroundColor Cyan
Write-Host "El backend necesita una cuenta del dominio (Ej: LAB-MH\usr_admin) para consultar RDS." -ForegroundColor Yellow
$ServiceUser = Read-Host "Usuario del dominio"
$SecurePass = Read-Host "Contraseña" -AsSecureString

$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePass)
$PlainPass = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)


# =====================================================================
# FASE 2: DESPLIEGUE DEL BACKEND (EXPRESS)
# =====================================================================
Write-Host "`n[FASE 2] Desplegando Backend..." -ForegroundColor Cyan

# 2.1 Detener servicio previo para liberar archivos
if (Get-Service -Name $ServiceName -ErrorAction SilentlyContinue) {
    try {
        Write-Host "  -> Deteniendo servicio antiguo de Node.js..."
        Stop-Service -Name $ServiceName -Force -ErrorAction Stop
        if (Test-Path $NssmTarget) { & $NssmTarget remove $ServiceName confirm | Out-Null }
        Start-Sleep -Seconds 2
    }
    catch {
        Write-Host "  -> [ADVERTENCIA] No se pudo detener el servicio limpiamente. Continuando..." -ForegroundColor DarkYellow
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
    Write-Host "  -> Instalando servicio persistente ($ServiceName)..."
    & $NssmTarget install $ServiceName "$NodePath" "`"$AppEntry`""
    & $NssmTarget set $ServiceName AppDirectory "$TargetBackend"
    & $NssmTarget set $ServiceName AppEnvironmentExtra "NODE_ENV=production" 
    & $NssmTarget set $ServiceName ObjectName "$ServiceUser" "$PlainPass"
    
    Start-Service -Name $ServiceName -ErrorAction Stop
    Write-Host "  -> Backend en línea y conectado al Active Directory." -ForegroundColor Green
}
catch {
    Write-Host "[ERROR] El backend se copió, pero falló al crear o iniciar el servicio." -ForegroundColor Red
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