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

# 1. Limpieza de compilaciones anteriores
Write-Host "`n[1/6] Limpiando entorno..." -ForegroundColor Yellow
if (Test-Path $ReleaseDir) { Remove-Item -Path $ReleaseDir -Recurse -Force }
if (-not (Test-Path $ReleasesDir)) { New-Item -ItemType Directory -Path $ReleasesDir | Out-Null }
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
Copy-Item -Path "$ProjectRoot\backend\.env" -Destination $TargetBack -Force
Copy-Item -Path "$ProjectRoot\backend\nssm.exe" -Destination $TargetBack -Force
Copy-Item -Path "$ProjectRoot\backend\node.exe" -Destination $TargetBack -Force

# --- Copiar Instalador ---
Copy-Item -Path "$ProjectRoot\install.ps1" -Destination $ReleaseDir -Force

# 6. Compresión Final
Write-Host "`n[6/7] Comprimiendo el paquete (ZIP)..." -ForegroundColor Yellow
Compress-Archive -Path "$ReleaseDir\*" -DestinationPath $ZipFile -Force
Remove-Item -Path $ReleaseDir -Recurse -Force

# 7. Generar instalador .exe autónomo (ZIP embebido como base64 via ps2exe)
Write-Host "`n[7/7] Generando instalador .exe autónomo..." -ForegroundColor Yellow

if (-not (Get-Command Invoke-ps2exe -ErrorAction SilentlyContinue)) {
    Write-Host "  -> Instalando módulo ps2exe (una sola vez)..." -ForegroundColor Yellow
    Install-Module -Name ps2exe -Scope CurrentUser -Force -ErrorAction Stop
    Import-Module ps2exe -Force
}

Write-Host "  -> Codificando paquete en base64 (puede tardar unos segundos)..."
$zipBytes  = [System.IO.File]::ReadAllBytes($ZipFile)
$zipBase64 = [Convert]::ToBase64String($zipBytes, 'InsertLineBreaks')

$LauncherPs1 = "$ReleasesDir\_launcher_tmp.ps1"
$ExeFile     = "$ReleasesDir\RDWeb-Portal-Installer-$Timestamp.exe"

# Genera el script lanzador que quedará compilado dentro del .exe
# - Al ejecutarse, decodifica el ZIP, lo extrae a %TEMP% y lanza install.ps1
Set-Content -Path $LauncherPs1 -Encoding UTF8 -Value @"
`$zipBase64 = @'
$zipBase64
'@

`$tempDir = "`$env:TEMP\RDWebInstall"
if (Test-Path `$tempDir) { Remove-Item `$tempDir -Recurse -Force }
New-Item -ItemType Directory -Path `$tempDir | Out-Null

`$zipPath = "`$tempDir\release.zip"
Write-Host "Extrayendo paquete de instalación..."
[System.IO.File]::WriteAllBytes(`$zipPath, [Convert]::FromBase64String(`$zipBase64.Trim()))
Expand-Archive -Path `$zipPath -DestinationPath `$tempDir -Force
Remove-Item `$zipPath -Force

`$installScript = "`$tempDir\install.ps1"
if (-not (Test-Path `$installScript)) {
    Write-Host "[ERROR] No se encontró install.ps1 dentro del paquete." -ForegroundColor Red
    Read-Host "Presiona Enter para salir..."
    Exit
}

Set-Location `$tempDir
& `$installScript
"@

Write-Host "  -> Compilando .exe con ps2exe..."
Invoke-ps2exe -InputFile $LauncherPs1 -OutputFile $ExeFile -RequireAdmin -ErrorAction Stop

# ps2exe puede mantener el archivo abierto brevemente tras compilar — reintentamos
$retries = 5
while ($retries -gt 0) {
    Start-Sleep -Milliseconds 500
    try { Remove-Item $LauncherPs1 -Force -ErrorAction Stop; break }
    catch { $retries-- }
}

Write-Host "`n========================================================" -ForegroundColor Green
Write-Host " ¡CONSTRUCCIÓN COMPLETADA CON ÉXITO!" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
Write-Host "ZIP de respaldo:"
Write-Host "  $ZipFile" -ForegroundColor DarkGray
Write-Host "Instalador EXE (distribuir este):"
Write-Host "  $ExeFile" -ForegroundColor Cyan
Write-Host ""
Read-Host "Presiona Enter para salir..."