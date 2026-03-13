# =====================================================================
# Constructor Automático de Release - Portal RD Web (Multi-Installer)
# =====================================================================
$ErrorActionPreference = "Stop"
$ProjectRoot = $PSScriptRoot
$Timestamp   = Get-Date -Format "yyyy-MM-dd_HH-mm"
$ReleasesDir = "$ProjectRoot\releases"
$ReleaseDir  = "$ProjectRoot\Release"
$ZipFile     = "$ReleasesDir\RDWeb-Portal-$Timestamp.zip"

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host " Iniciando Construcción y Empaquetado de Producción" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

# ── 1. Selección del tipo de Backend ──────────────────────────────────
Write-Host ""
Write-Host "Seleccione el tipo de backend a empaquetar:" -ForegroundColor Magenta
Write-Host "  [1] Express (Node.js)  — actual" -ForegroundColor White
Write-Host "  [2] Python  (FastAPI)  — nuevo" -ForegroundColor White
Write-Host ""
$choiceBack = Read-Host "Opcion (1/2) [por defecto: 1]"
if ($choiceBack -eq "2") {
    $BackendType = "python"
    Write-Host "  -> Backend seleccionado: Python (FastAPI)" -ForegroundColor Green
} else {
    $BackendType = "express"
    Write-Host "  -> Backend seleccionado: Express (Node.js)" -ForegroundColor Green
}

# ── 2. Selección del Motor de Instalación ─────────────────────────────
Write-Host ""
Write-Host "Seleccione el motor del instalador a utilizar:" -ForegroundColor Magenta
Write-Host "  [1] Inno Setup (Estable)" -ForegroundColor White
Write-Host "  [2] NSIS       (Nuevo / Ligero)" -ForegroundColor White
Write-Host ""
$choiceInst = Read-Host "Opcion (1/2) [por defecto: 2]"
if ($choiceInst -eq "1") {
    $InstallerType = "inno"
    Write-Host "  -> Instalador seleccionado: Inno Setup" -ForegroundColor Green
} else {
    $InstallerType = "nsis"
    Write-Host "  -> Instalador seleccionado: NSIS" -ForegroundColor Green
}

# 1. Limpieza de compilaciones anteriores
Write-Host "`n[1/7] Limpiando entorno..." -ForegroundColor Yellow
if (Test-Path $ReleaseDir) { Remove-Item -Path $ReleaseDir -Recurse -Force }
if (-not (Test-Path $ReleasesDir)) { New-Item -ItemType Directory -Path $ReleasesDir | Out-Null }
New-Item -ItemType Directory -Path $ReleaseDir | Out-Null

# 2. Instalación de dependencias del Frontend
Write-Host "`n[2/7] Instalando dependencias del Frontend (Angular)..." -ForegroundColor Yellow
Set-Location "$ProjectRoot\frontend"
if (Test-Path "node_modules") { Remove-Item -Path "node_modules" -Recurse -Force }
cmd /c "npm install"
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Falló la instalación de dependencias de Angular." -ForegroundColor Red
    Exit
}

# 3. Compilación del Frontend
Write-Host "`n[3/7] Compilando el Frontend para Producción..." -ForegroundColor Yellow
cmd /c "npm run build -- --configuration production"
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Falló la compilación de Angular." -ForegroundColor Red
    Exit
}

# 4. Preparación del Backend
if ($BackendType -eq "python") {
    Write-Host "`n[4/7] Compilando Backend Python (PyInstaller)..." -ForegroundColor Yellow
    Set-Location "$ProjectRoot\backend-py"
    if (-not (Get-Command poetry -ErrorAction SilentlyContinue)) {
        Write-Host "[ERROR] Poetry no encontrado. Instalelo desde: https://python-poetry.org" -ForegroundColor Red
        Exit
    }
    Write-Host "  -> Instalando dependencias con Poetry..." -ForegroundColor DarkGray
    cmd /c "poetry install"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Fallo la instalacion de dependencias de Python." -ForegroundColor Red
        Exit
    }
    if (Test-Path "dist") { Remove-Item -Path "dist" -Recurse -Force }
    if (Test-Path "build") { Remove-Item -Path "build" -Recurse -Force }
    Write-Host "  -> Empaquetando con PyInstaller..." -ForegroundColor DarkGray
    cmd /c "poetry run pyinstaller backend.spec --clean --noconfirm"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Fallo la compilacion de PyInstaller." -ForegroundColor Red
        Exit
    }
    if (-not (Test-Path "$ProjectRoot\backend-py\dist\main.exe")) {
        Write-Host "[ERROR] No se genero el ejecutable dist\main.exe" -ForegroundColor Red
        Exit
    }
} else {
    Write-Host "`n[4/7] Instalando dependencias del Backend (Solo Producción)..." -ForegroundColor Yellow
    Set-Location "$ProjectRoot\backend"
    if (Test-Path "node_modules") { Remove-Item -Path "node_modules" -Recurse -Force }
    cmd /c "npm install --production"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Falló la instalación de dependencias del backend." -ForegroundColor Red
        Exit
    }
}

# 5. Ensamblaje de la carpeta de Release
Write-Host "`n[5/7] Ensamblando archivos para el paquete final..." -ForegroundColor Yellow
Set-Location $ProjectRoot

$TargetFront = New-Item -ItemType Directory -Path "$ReleaseDir\frontend"
$TargetBack = New-Item -ItemType Directory -Path "$ReleaseDir\backend"

# --- Copiar Frontend ---
$AngularDist = "$ProjectRoot\frontend\dist\frontend\browser"
if (-not (Test-Path $AngularDist)) {
    Write-Host "[ERROR] No se encontró la carpeta compilada en: $AngularDist" -ForegroundColor Red
    Exit
}
Copy-Item -Path "$AngularDist\*" -Destination $TargetFront -Recurse -Force

$WebConfigPath = "$ProjectRoot\frontend\web.config"
if (Test-Path $WebConfigPath) {
    Copy-Item -Path $WebConfigPath -Destination $TargetFront -Force
}

# Copiar los MSIs de prerrequisitos
Copy-Item -Path "$ProjectRoot\prereqs" -Destination $ReleaseDir -Recurse -Force

# --- Copiar Backend ---
if ($BackendType -eq "python") {
    Copy-Item -Path "$ProjectRoot\backend-py\dist\main.exe" -Destination $TargetBack -Force
    Copy-Item -Path "$ProjectRoot\backend\nssm.exe" -Destination $TargetBack -Force
} else {
    Copy-Item -Path "$ProjectRoot\backend\src" -Destination $TargetBack -Recurse -Force
    Copy-Item -Path "$ProjectRoot\backend\node_modules" -Destination $TargetBack -Recurse -Force
    Copy-Item -Path "$ProjectRoot\backend\package.json" -Destination $TargetBack -Force
    Copy-Item -Path "$ProjectRoot\backend\nssm.exe" -Destination $TargetBack -Force
    Copy-Item -Path "$ProjectRoot\backend\node.exe" -Destination $TargetBack -Force
}

# --- Copiar Scripts auxiliares ---
if (Test-Path "$ProjectRoot\scripts") {
    Copy-Item -Path "$ProjectRoot\scripts" -Destination $ReleaseDir -Recurse -Force
}

# --- Copiar Assets (Necesario para que NSIS encuentre el icono al compilar) ---
if (Test-Path "$ProjectRoot\assets") {
    Copy-Item -Path "$ProjectRoot\assets" -Destination $ReleaseDir -Recurse -Force
}

# 6. Compresión Final (ZIP de respaldo)
Write-Host "`n[6/7] Comprimiendo el paquete ZIP (respaldo)..." -ForegroundColor Yellow
Compress-Archive -Path "$ReleaseDir\*" -DestinationPath $ZipFile -Force

# 7. Compilación del Instalador
Write-Host "`n[7/7] Compilando instalador con $InstallerType..." -ForegroundColor Yellow

if ($InstallerType -eq "inno") {
    # =================================================================
    # COMPILACIÓN INNO SETUP
    # =================================================================
    $ISCC = $null
    $InnoPaths = @("${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe", "$env:ProgramFiles\Inno Setup 6\ISCC.exe")
    foreach ($p in $InnoPaths) { if (Test-Path $p) { $ISCC = $p; break } }
    if (-not $ISCC) { $found = Get-Command ISCC.exe -ErrorAction SilentlyContinue; if ($found) { $ISCC = $found.Source } }
    
    if (-not $ISCC) {
        Write-Host "[ERROR] No se encontró Inno Setup (ISCC.exe)." -ForegroundColor Red
        Exit
    }

    $IssFile = "$ProjectRoot\installer.iss"
    $ExeFile = "$ReleasesDir\RDWeb-Portal-Installer-Inno-$Timestamp.exe"
    
    Write-Host "  -> Usando: $ISCC" -ForegroundColor DarkGray
    Set-Location $ProjectRoot
    & $ISCC /O"$ReleasesDir" /F"RDWeb-Portal-Installer-Inno-$Timestamp" `
        /DMyAppVersion="1.0.0" /DBackendType="$BackendType" `
        /DSrcBackend="$ReleaseDir\backend" /DSrcFrontend="$ReleaseDir\frontend" `
        /DSrcPrereqs="$ReleaseDir\prereqs" /DSrcWebConfig="$ReleaseDir\frontend\web.config" `
        "$IssFile"
        
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Falló la compilación de Inno Setup." -ForegroundColor Red
        Exit
    }

} else {
    # =================================================================
    # COMPILACIÓN NSIS
    # =================================================================
    $Makensis = $null
    $NsisPaths = @("${env:ProgramFiles(x86)}\NSIS\makensis.exe", "$env:ProgramFiles\NSIS\makensis.exe")
    foreach ($p in $NsisPaths) { if (Test-Path $p) { $Makensis = $p; break } }
    if (-not $Makensis) { $found = Get-Command makensis.exe -ErrorAction SilentlyContinue; if ($found) { $Makensis = $found.Source } }
    
    if (-not $Makensis) {
        Write-Host "[ERROR] No se encontró NSIS (makensis.exe)." -ForegroundColor Red
        Write-Host "Descárgalo de: https://nsis.sourceforge.io/Download" -ForegroundColor Yellow
        Exit
    }

    # Copiamos el script NSIS a la carpeta Release temporal para que las rutas relativas funcionen
    $NsiFileSource = "$ProjectRoot\installer.nsi"
    $NsiFileTemp   = "$ReleaseDir\installer.nsi"
    Copy-Item -Path $NsiFileSource -Destination $NsiFileTemp -Force
    
    $ExeFile = "$ReleasesDir\RDWeb-Portal-Installer-NSIS-$Timestamp.exe"
    
    Write-Host "  -> Usando: $Makensis" -ForegroundColor DarkGray
    
    # Cambiamos al directorio Release para que NSIS empaquete los archivos ensamblados
    Set-Location $ReleaseDir
    
    # Pasamos la ruta absoluta mediante la variable DOutFileExe
    & $Makensis /DMyAppVersion="1.0.0" /DBackendType="$BackendType" /DOutFileExe="$ExeFile" "installer.nsi"
    
    # Volvemos a la raíz
    Set-Location $ProjectRoot

    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Falló la compilación de NSIS." -ForegroundColor Red
        Exit
    }
}

# Limpiar carpeta temporal de Release
Remove-Item -Path $ReleaseDir -Recurse -Force

Write-Host "`n========================================================" -ForegroundColor Green
Write-Host " CONSTRUCCION COMPLETADA CON EXITO!" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
Write-Host "Backend empaquetado: $BackendType" -ForegroundColor Cyan
Write-Host "ZIP de respaldo:"
Write-Host "  $ZipFile" -ForegroundColor DarkGray
Write-Host "Instalador EXE ($InstallerType):"
Write-Host "  $ExeFile" -ForegroundColor Cyan
Write-Host ""
Read-Host "Presiona Enter para salir..."