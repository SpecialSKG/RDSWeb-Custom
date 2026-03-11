# =====================================================================
# Constructor Automático de Release - Portal RD Web (Zero-Dependencies)
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

# ── Selección del tipo de Backend ─────────────────────────────────────
Write-Host ""
Write-Host "Seleccione el tipo de backend a empaquetar:" -ForegroundColor Magenta
Write-Host "  [1] Express (Node.js)  — actual" -ForegroundColor White
Write-Host "  [2] Python  (FastAPI)  — nuevo" -ForegroundColor White
Write-Host ""
$choice = Read-Host "Opcion (1/2) [por defecto: 1]"
if ($choice -eq "2") {
    $BackendType = "python"
    Write-Host "  -> Backend seleccionado: Python (FastAPI)" -ForegroundColor Green
} else {
    $BackendType = "express"
    Write-Host "  -> Backend seleccionado: Express (Node.js)" -ForegroundColor Green
}

# 1. Limpieza de compilaciones anteriores
Write-Host "`n[1/7] Limpiando entorno..." -ForegroundColor Yellow
if (Test-Path $ReleaseDir) { Remove-Item -Path $ReleaseDir -Recurse -Force }
if (-not (Test-Path $ReleasesDir)) { New-Item -ItemType Directory -Path $ReleasesDir | Out-Null }
New-Item -ItemType Directory -Path $ReleaseDir | Out-Null

# 2. Instalación de dependencias del Frontend
Write-Host "`n[2/7] Instalando dependencias del Frontend (Angular)..." -ForegroundColor Yellow
Set-Location "$ProjectRoot\frontend"
# Limpieza preventiva para clones frescos
if (Test-Path "node_modules") { Remove-Item -Path "node_modules" -Recurse -Force }
cmd /c "npm install"
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Falló la instalación de dependencias de Angular." -ForegroundColor Red
    Exit
}

# 3. Compilación del Frontend (Usando CLI local vía npm run)
Write-Host "`n[3/7] Compilando el Frontend para Producción..." -ForegroundColor Yellow
# Al usar 'npm run build', npm utiliza el binario local de Angular, sin requerir instalación global
cmd /c "npm run build -- --configuration production"
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Falló la compilación de Angular." -ForegroundColor Red
    Exit
}

# 4. Preparación del Backend
if ($BackendType -eq "python") {
    Write-Host "`n[4/7] Compilando Backend Python (PyInstaller)..." -ForegroundColor Yellow
    Set-Location "$ProjectRoot\backend-py"

    # Verificar que Poetry esté disponible
    if (-not (Get-Command poetry -ErrorAction SilentlyContinue)) {
        Write-Host "[ERROR] Poetry no encontrado. Instalelo desde: https://python-poetry.org" -ForegroundColor Red
        Exit
    }

    # Instalar dependencias (incluye PyInstaller en dev)
    Write-Host "  -> Instalando dependencias con Poetry..." -ForegroundColor DarkGray
    cmd /c "poetry install"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Fallo la instalacion de dependencias de Python." -ForegroundColor Red
        Exit
    }

    # Limpiar compilaciones anteriores de PyInstaller
    if (Test-Path "dist") { Remove-Item -Path "dist" -Recurse -Force }
    if (Test-Path "build") { Remove-Item -Path "build" -Recurse -Force }

    # Empaquetar con PyInstaller
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
# Copiamos los archivos estáticos generados
Copy-Item -Path "$AngularDist\*" -Destination $TargetFront -Recurse -Force

# Copiamos el web.config a la carpeta frontend del release
$WebConfigPath = "$ProjectRoot\frontend\web.config"
if (Test-Path $WebConfigPath) {
    Write-Host "  -> Archivo web.config encontrado y anexado al frontend." -ForegroundColor Cyan
    Copy-Item -Path $WebConfigPath -Destination $TargetFront -Force
}
else {
    Write-Host "  -> [ADVERTENCIA] No se encontró el web.config en $ProjectRoot\frontend" -ForegroundColor Magenta
}

# Copiar los MSIs de prerrequisitos
Copy-Item -Path "$ProjectRoot\prereqs" -Destination $ReleaseDir -Recurse -Force

# --- Copiar Backend ---
if ($BackendType -eq "python") {
    # Python: solo el ejecutable empaquetado + nssm
    Copy-Item -Path "$ProjectRoot\backend-py\dist\main.exe" -Destination $TargetBack -Force
    Copy-Item -Path "$ProjectRoot\backend\nssm.exe" -Destination $TargetBack -Force
    if (Test-Path "$ProjectRoot\backend-py\.env") {
        Copy-Item -Path "$ProjectRoot\backend-py\.env" -Destination $TargetBack -Force
    } else {
        Write-Host "  -> [NOTA] No se encontro .env — el instalador lo generara." -ForegroundColor DarkYellow
    }
} else {
    # Express: src, node_modules, package.json, binarios
    Copy-Item -Path "$ProjectRoot\backend\src" -Destination $TargetBack -Recurse -Force
    Copy-Item -Path "$ProjectRoot\backend\node_modules" -Destination $TargetBack -Recurse -Force
    Copy-Item -Path "$ProjectRoot\backend\package.json" -Destination $TargetBack -Force
    if (Test-Path "$ProjectRoot\backend\.env") {
        Copy-Item -Path "$ProjectRoot\backend\.env" -Destination $TargetBack -Force
    } else {
        Write-Host "  -> [NOTA] No se encontró .env — recuerde crearlo en el servidor." -ForegroundColor DarkYellow
    }
    Copy-Item -Path "$ProjectRoot\backend\nssm.exe" -Destination $TargetBack -Force
    Copy-Item -Path "$ProjectRoot\backend\node.exe" -Destination $TargetBack -Force
}

# --- Copiar Scripts auxiliares (también en ZIP de respaldo) ---
if (Test-Path "$ProjectRoot\scripts") {
    Copy-Item -Path "$ProjectRoot\scripts" -Destination $ReleaseDir -Recurse -Force
    Write-Host "  -> Scripts auxiliares copiados al Release." -ForegroundColor Cyan
}

# 6. Compresión Final (ZIP de respaldo)
Write-Host "`n[6/7] Comprimiendo el paquete ZIP (respaldo)..." -ForegroundColor Yellow
Compress-Archive -Path "$ReleaseDir\*" -DestinationPath $ZipFile -Force

# 7. Compilar instalador con Inno Setup (ISCC)
Write-Host "`n[7/7] Compilando instalador con Inno Setup..." -ForegroundColor Yellow

$ISCC = $null
$InnoPaths = @(
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
)
foreach ($p in $InnoPaths) {
    if (Test-Path $p) { $ISCC = $p; break }
}
if (-not $ISCC) {
    $found = Get-Command ISCC.exe -ErrorAction SilentlyContinue
    if ($found) { $ISCC = $found.Source }
}
if (-not $ISCC) {
    Write-Host "[ERROR] No se encontró Inno Setup (ISCC.exe)." -ForegroundColor Red
    Write-Host "Descárgalo de: https://jrsoftware.org/isdownload.php" -ForegroundColor Yellow
    Write-Host "El ZIP de respaldo se generó correctamente en: $ZipFile" -ForegroundColor DarkGray
    Remove-Item -Path $ReleaseDir -Recurse -Force
    Read-Host "Presiona Enter para salir..."
    Exit
}

$IssFile = "$ProjectRoot\installer.iss"
$ExeFile = "$ReleasesDir\RDWeb-Portal-Installer-$Timestamp.exe"

Write-Host "  -> Usando: $ISCC" -ForegroundColor DarkGray
Set-Location $ProjectRoot
& $ISCC /O"$ReleasesDir" /F"RDWeb-Portal-Installer-$Timestamp" `
    /DMyAppVersion="1.0.0" `
    /DBackendType="$BackendType" `
    /DSrcBackend="$ReleaseDir\backend" `
    /DSrcFrontend="$ReleaseDir\frontend" `
    /DSrcPrereqs="$ReleaseDir\prereqs" `
    /DSrcWebConfig="$ReleaseDir\frontend\web.config" `
    "$IssFile"
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Falló la compilación de Inno Setup." -ForegroundColor Red
    Remove-Item -Path $ReleaseDir -Recurse -Force
    Read-Host "Presiona Enter para salir..."
    Exit
}

# Limpiar carpeta temporal de Release (el contenido ya está en el ZIP y el EXE)
Remove-Item -Path $ReleaseDir -Recurse -Force

Write-Host "`n========================================================" -ForegroundColor Green
Write-Host " CONSTRUCCION COMPLETADA CON EXITO! ($BackendType)" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
Write-Host "Backend empaquetado: $BackendType" -ForegroundColor Cyan
Write-Host "ZIP de respaldo:"
Write-Host "  $ZipFile" -ForegroundColor DarkGray
Write-Host "Instalador EXE (distribuir este):"
Write-Host "  $ExeFile" -ForegroundColor Cyan
Write-Host ""
Write-Host "Nota: El instalador fue generado con Inno Setup." -ForegroundColor DarkGray
Write-Host "      Incluye desinstalador automático desde 'Agregar o quitar programas'." -ForegroundColor DarkGray
Write-Host ""
Read-Host "Presiona Enter para salir..."