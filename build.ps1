# =====================================================================
# Constructor Automático de Release - Portal RD Web (Zero-Dependencies)
# =====================================================================
$ErrorActionPreference = "Stop"
$ProjectRoot = $PSScriptRoot
$ReleaseDir = "$ProjectRoot\Release"
$ZipFile = "$ProjectRoot\RDWeb-Portal-Release.zip"

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host " Iniciando Construcción y Empaquetado de Producción" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

# 1. Limpieza de compilaciones anteriores
Write-Host "`n[1/6] Limpiando entorno..." -ForegroundColor Yellow
if (Test-Path $ReleaseDir) { Remove-Item -Path $ReleaseDir -Recurse -Force }
if (Test-Path $ZipFile) { Remove-Item -Path $ZipFile -Force }
New-Item -ItemType Directory -Path $ReleaseDir | Out-Null

# 2. Instalación de dependencias del Frontend
Write-Host "`n[2/6] Instalando dependencias del Frontend (Angular)..." -ForegroundColor Yellow
Set-Location "$ProjectRoot\frontend"
# Limpieza preventiva para clones frescos
if (Test-Path "node_modules") { Remove-Item -Path "node_modules" -Recurse -Force }
cmd /c "npm install"
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Falló la instalación de dependencias de Angular." -ForegroundColor Red
    Exit
}

# 3. Compilación del Frontend (Usando CLI local vía npm run)
Write-Host "`n[3/6] Compilando el Frontend para Producción..." -ForegroundColor Yellow
# Al usar 'npm run build', npm utiliza el binario local de Angular, sin requerir instalación global
cmd /c "npm run build -- --configuration production"
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Falló la compilación de Angular." -ForegroundColor Red
    Exit
}

# 4. Preparación del Backend
Write-Host "`n[4/6] Instalando dependencias del Backend (Solo Producción)..." -ForegroundColor Yellow
Set-Location "$ProjectRoot\backend"
if (Test-Path "node_modules") { Remove-Item -Path "node_modules" -Recurse -Force }
# Instala solo dependencias de prod (ignora devDependencies como nodemon, jest, etc)
cmd /c "npm install --production"
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Falló la instalación de dependencias del backend." -ForegroundColor Red
    Exit
}

# 5. Ensamblaje de la carpeta de Release
Write-Host "`n[5/6] Ensamblando archivos para el paquete final..." -ForegroundColor Yellow
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
Copy-Item -Path "$ProjectRoot\backend\src" -Destination $TargetBack -Recurse -Force
Copy-Item -Path "$ProjectRoot\backend\node_modules" -Destination $TargetBack -Recurse -Force
Copy-Item -Path "$ProjectRoot\backend\package.json" -Destination $TargetBack -Force
Copy-Item -Path "$ProjectRoot\backend\.env.template" -Destination $TargetBack -Force
Copy-Item -Path "$ProjectRoot\backend\nssm.exe" -Destination $TargetBack -Force

# --- Copiar Instalador ---
Copy-Item -Path "$ProjectRoot\install.ps1" -Destination $ReleaseDir -Force

# 6. Compresión Final
Write-Host "`n[6/6] Comprimiendo el paquete (ZIP)..." -ForegroundColor Yellow
Compress-Archive -Path "$ReleaseDir\*" -DestinationPath $ZipFile -Force
Remove-Item -Path $ReleaseDir -Recurse -Force

Write-Host "`n========================================================" -ForegroundColor Green
Write-Host " ¡CONSTRUCCIÓN COMPLETADA CON ÉXITO!" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
Write-Host "Tu paquete maestro está listo en:"
Write-Host $ZipFile -ForegroundColor Cyan
Write-Host ""
Read-Host "Presiona Enter para salir..."