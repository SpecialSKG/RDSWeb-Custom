# Integración con el Pipeline de Despliegue

Este documento describe los cambios necesarios para integrar el backend Python en
el pipeline existente (build.ps1, installer.iss, scripts NSSM).

---

## 1. Cambios en `setup-backend-service.ps1`

El script actual apunta a `node.exe` e `index.js`.  Solo hay que cambiar las
rutas al nuevo ejecutable `main.exe`:

```diff
- $NodeExe     = "$BackendDir\node.exe"
- $AppEntry    = "$BackendDir\src\index.js"
+ $MainExe     = "$BackendDir\main.exe"

- if (-not (Test-Path $NodeExe))  { throw "node.exe no encontrado en: $NodeExe" }
- if (-not (Test-Path $AppEntry)) { throw "index.js no encontrado en: $AppEntry" }
+ if (-not (Test-Path $MainExe))  { throw "main.exe no encontrado en: $MainExe" }

# Al instalar con NSSM:
- Invoke-Nssm @('install', $ServiceName, $NodeExe, "`"$AppEntry`"")
+ Invoke-Nssm @('install', $ServiceName, $MainExe)

# AppDirectory se mantiene igual (apunta a $BackendDir donde vive el .env).
```

Ya **no** se necesitan `node.exe`, `node_modules/` ni `src/` en el paquete de
release; el único archivo ejecutable es `main.exe` y lee el `.env` desde su
propio directorio.

---

## 2. Cambios en `build.ps1`

Reemplazar la sección del backend (pasos 4 y 5) por:

```powershell
# 4. Compilar el Backend (Python → .exe via PyInstaller)
Write-Host "`n[4/7] Compilando el Backend Python..." -ForegroundColor Yellow
Set-Location "$ProjectRoot\backend-py"
cmd /c "poetry install"
cmd /c "poetry run pyinstaller backend.spec --noconfirm"

# 5. Ensamblar Release
$BackendExe = "$ProjectRoot\backend-py\dist\main.exe"
if (-not (Test-Path $BackendExe)) {
    Write-Host "[ERROR] No se generó main.exe" -ForegroundColor Red
    Exit
}
Copy-Item -Path $BackendExe -Destination $TargetBack -Force
# El .env lo genera el instalador en runtime; copiar el ejemplo como referencia
Copy-Item -Path "$ProjectRoot\backend-py\.env.example" -Destination "$TargetBack\.env.example" -Force
# NSSM sigue siendo necesario
Copy-Item -Path "$ProjectRoot\backend\nssm.exe" -Destination $TargetBack -Force
```

Ya **no** se copian `node.exe`, `node_modules/`, `package.json` ni `src/`.

---

## 3. Cambios en `installer.iss`

Sección `[Files]` del backend — reemplazar:

```diff
- Source: "{#SrcBackend}\node.exe"; DestDir: "{app}\backend"; ...
- Source: "{#SrcBackend}\src\*"; DestDir: "{app}\backend\src"; ...
- Source: "{#SrcBackend}\node_modules\*"; DestDir: "{app}\backend\node_modules"; ...
+ Source: "{#SrcBackend}\main.exe"; DestDir: "{app}\backend"; Flags: ignoreversion
```

La generación del `.env` en `[Code]` (función `GenerateEnvFile()`) sigue igual
porque los nombres de las variables son idénticos.

---

## 4. Logging y NSSM

El backend Python escribe toda su salida a `stdout`/`stderr` de forma no
bufferizada (logging handler apunta a `sys.stdout`).  La configuración de
NSSM existente (`AppStdout`, `AppStderr`, `AppRotateFiles`, `AppRotateBytes`)
funciona sin cambios.

---

## 5. Lectura dinámica del .env

`python-dotenv` carga el `.env` desde el directorio del ejecutable
(`sys.executable` → carpeta padre).  Cuando el installer genera el `.env` en
`{app}\backend\.env`, el `main.exe` ubicado en `{app}\backend\main.exe` lo
encontrará automáticamente.
