<#
.SYNOPSIS
    Constructor y Empaquetador de Release para RD Web Portal.

.DESCRIPTION
    Este script automatiza la limpieza, compilación (Frontend y Backend),
    ensamblaje y empaquetado (ZIP y EXE) del proyecto RD Web Portal.
    Diseñado para ser ejecutado en entornos locales o pipelines de CI/CD.

.PARAMETER BackendType
    Especifica el motor del backend a compilar. Valores permitidos: 'express', 'python'. Default: 'express'.

.PARAMETER InstallerType
    Especifica el motor del instalador a utilizar. Valores permitidos: 'inno', 'nsis'. Default: 'nsis'.

.PARAMETER AppVersion
    Versión de la aplicación a empaquetar. Default: '1.0.0'.

.EXAMPLE
    .\build.ps1 -BackendType python -InstallerType nsis -AppVersion 1.2.0

.EXAMPLE
    .\build.ps1 -Verbose
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [ValidateSet("express", "python")]
    [string]$BackendType = "python",

    [Parameter(Mandatory = $false)]
    [ValidateSet("inno", "nsis")]
    [string]$InstallerType = "nsis",

    [Parameter(Mandatory = $false)]
    [string]$AppVersion = "1.0.2"
)

# ---------------------------------------------------------------------
# Configuración Global y Variables de Entorno
# ---------------------------------------------------------------------
$ErrorActionPreference = "Stop"
$InformationPreference = "Continue"

$ProjectRoot = $PSScriptRoot

# Single source-of-truth: VERSION file at repository root.
# Behavior:
# - If user passes -AppVersion, persist it to VERSION so edits only required in one place.
# - If user does NOT pass -AppVersion, read VERSION (if present) and use it.
$VersionFile = Join-Path -Path $ProjectRoot -ChildPath "VERSION"
if ($PSBoundParameters.ContainsKey('AppVersion')) {
    try {
        Set-Content -Path $VersionFile -Value $AppVersion -Encoding UTF8
    } catch {
        New-Item -Path $VersionFile -ItemType File -Force | Out-Null
        Set-Content -Path $VersionFile -Value $AppVersion -Encoding UTF8
    }
} else {
    if (Test-Path -Path $VersionFile) {
        $fileVersion = (Get-Content -Path $VersionFile -Raw -ErrorAction SilentlyContinue).Trim()
        if ($fileVersion) { $AppVersion = $fileVersion } else { Set-Content -Path $VersionFile -Value $AppVersion -Encoding UTF8 }
    } else {
        Set-Content -Path $VersionFile -Value $AppVersion -Encoding UTF8
    }
}

$Timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm"
$ReleasesDir = Join-Path -Path $ProjectRoot -ChildPath "releases"
$ReleaseDir = Join-Path -Path $ProjectRoot -ChildPath "Release"
$ZipFile = Join-Path -Path $ReleasesDir -ChildPath "RDWeb-Portal-$Timestamp.zip"

# ---------------------------------------------------------------------
# Funciones Auxiliares (Privadas)
# ---------------------------------------------------------------------

function Invoke-ExternalCommand {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Command,
        
        [Parameter(Mandatory = $false)]
        [string]$Arguments = "",

        [Parameter(Mandatory = $true)]
        [string]$ErrorMessage
    )
    
    # Envolvemos TODO el comando en comillas dobles para que cmd.exe no se confunda 
    # si hay múltiples comillas en las rutas (ej. espacios en "Program Files").
    $CmdArgs = "/c `"$Command $Arguments`""
    
    Write-Verbose "Ejecutando: cmd.exe $CmdArgs"
    
    $process = Start-Process -FilePath "cmd.exe" -ArgumentList $CmdArgs -Wait -NoNewWindow -PassThru
    
    if ($process.ExitCode -ne 0) {
        throw "$ErrorMessage (Exit Code: $($process.ExitCode))"
    }
}

function Clear-BuildEnvironment {
    [CmdletBinding()]
    param ()
    Write-Information "[1/7] Limpiando entorno de compilación..."
    
    if (Test-Path -Path $ReleaseDir) { 
        Remove-Item -Path $ReleaseDir -Recurse -Force 
    }
    if (-not (Test-Path -Path $ReleasesDir)) { 
        New-Item -ItemType Directory -Path $ReleasesDir | Out-Null 
    }
    New-Item -ItemType Directory -Path $ReleaseDir | Out-Null
}

function Invoke-BuildFrontendWebApp {
    [CmdletBinding()]
    param ()
    Write-Information "[2/7] Preparando y compilando Frontend (Angular)..."
    
    $FrontDir = Join-Path -Path $ProjectRoot -ChildPath "frontend"
    Set-Location -Path $FrontDir

    if (Test-Path -Path "node_modules") { 
        Remove-Item -Path "node_modules" -Recurse -Force 
    }

    Invoke-ExternalCommand -Command "npm" -Arguments "install" -ErrorMessage "Falló la instalación de dependencias de Angular."
    
    Write-Information "[3/7] Compilando el Frontend para Producción..."
    Invoke-ExternalCommand -Command "npm" -Arguments "run build -- --configuration production" -ErrorMessage "Falló la compilación de Angular."
}

function Invoke-BuildBackendApp {
    [CmdletBinding()]
    param ([string]$Type)
    Write-Information "[4/7] Preparando y compilando Backend ($Type)..."

    if ($Type -eq "python") {
        $BackDir = Join-Path -Path $ProjectRoot -ChildPath "backend-py"
        Set-Location -Path $BackDir

        if (-not (Get-Command poetry -ErrorAction SilentlyContinue)) {
            throw "Poetry no encontrado. Instálelo desde: https://python-poetry.org"
        }

        Invoke-ExternalCommand -Command "poetry" -Arguments "install" -ErrorMessage "Falló la instalación de dependencias de Python."

        foreach ($dir in @("dist", "build")) {
            if (Test-Path -Path $dir) { Remove-Item -Path $dir -Recurse -Force }
        }

        Invoke-ExternalCommand -Command "poetry" -Arguments "run pyinstaller backend.spec --clean --noconfirm" -ErrorMessage "Falló la compilación de PyInstaller."

        if (-not (Test-Path -Path (Join-Path -Path $BackDir -ChildPath "dist\main.exe"))) {
            throw "No se generó el ejecutable dist\main.exe"
        }
    } 
    else {
        $BackDir = Join-Path -Path $ProjectRoot -ChildPath "backend"
        Set-Location -Path $BackDir

        if (Test-Path -Path "node_modules") { 
            Remove-Item -Path "node_modules" -Recurse -Force 
        }

        Invoke-ExternalCommand -Command "npm" -Arguments "install --production" -ErrorMessage "Falló la instalación de dependencias de Express."
    }
}

function Publish-ReleaseArtifacts {
    [CmdletBinding()]
    param ([string]$Type)
    Write-Information "[5/7] Ensamblando archivos para el paquete final..."
    
    Set-Location -Path $ProjectRoot

    $TargetFront = New-Item -ItemType Directory -Path (Join-Path -Path $ReleaseDir -ChildPath "frontend")
    $TargetBack = New-Item -ItemType Directory -Path (Join-Path -Path $ReleaseDir -ChildPath "backend")

    # Frontend
    $AngularDist = Join-Path -Path $ProjectRoot -ChildPath "frontend\dist\frontend\browser"
    if (-not (Test-Path -Path $AngularDist)) {
        throw "No se encontró la carpeta compilada del frontend en: $AngularDist"
    }
    Copy-Item -Path "$AngularDist\*" -Destination $TargetFront -Recurse -Force

    $WebConfigPath = Join-Path -Path $ProjectRoot -ChildPath "frontend\web.config"
    if (Test-Path -Path $WebConfigPath) {
        Copy-Item -Path $WebConfigPath -Destination $TargetFront -Force
    }

    # Prerrequisitos y Assets
    foreach ($folder in @("prereqs", "scripts", "assets")) {
        $sourcePath = Join-Path -Path $ProjectRoot -ChildPath $folder
        if (Test-Path -Path $sourcePath) {
            Copy-Item -Path $sourcePath -Destination $ReleaseDir -Recurse -Force
        }
    }

    # Backend
    if ($Type -eq "python") {
        Copy-Item -Path (Join-Path -Path $ProjectRoot -ChildPath "backend-py\dist\main.exe") -Destination $TargetBack -Force
        Copy-Item -Path (Join-Path -Path $ProjectRoot -ChildPath "backend\nssm.exe") -Destination $TargetBack -Force
    } 
    else {
        Copy-Item -Path (Join-Path -Path $ProjectRoot -ChildPath "backend\src") -Destination $TargetBack -Recurse -Force
        Copy-Item -Path (Join-Path -Path $ProjectRoot -ChildPath "backend\node_modules") -Destination $TargetBack -Recurse -Force
        Copy-Item -Path (Join-Path -Path $ProjectRoot -ChildPath "backend\package.json") -Destination $TargetBack -Force
        
        foreach ($file in @("nssm.exe", "node.exe")) {
            $filePath = Join-Path -Path $ProjectRoot -ChildPath "backend\$file"
            if (Test-Path -Path $filePath) {
                Copy-Item -Path $filePath -Destination $TargetBack -Force
            }
        }
    }

    Write-Information "[6/7] Comprimiendo el paquete ZIP de respaldo..."
    Compress-Archive -Path "$ReleaseDir\*" -DestinationPath $ZipFile -Force
}

function New-InstallerPackage {
    [CmdletBinding()]
    param (
        [string]$InstType,
        [string]$BackType,
        [string]$Version
    )
    Write-Information "[7/7] Compilando instalador con $InstType..."

    if ($InstType -eq "inno") {
        $isccPaths = @(
            "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe", 
            "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
        )
        $Compiler = $isccPaths | Where-Object { Test-Path -Path $_ } | Select-Object -First 1
        
        if (-not $Compiler) { $Compiler = (Get-Command ISCC.exe -ErrorAction SilentlyContinue).Source }
        if (-not $Compiler) { throw "No se encontró Inno Setup (ISCC.exe)." }

        $IssFile = Join-Path -Path $ProjectRoot -ChildPath "installer.iss"
        $InstallerArgs = @(
            "/O`"$ReleasesDir`"",
            "/F`"RDWeb-Portal-Installer-Inno-$Version`"",
            "/DMyAppVersion=`"$Version`"",
            "/DBackendType=`"$BackType`"",
            "/DSrcBackend=`"$ReleaseDir\backend`"",
            "/DSrcFrontend=`"$ReleaseDir\frontend`"",
            "/DSrcPrereqs=`"$ReleaseDir\prereqs`"",
            "/DSrcWebConfig=`"$ReleaseDir\frontend\web.config`"",
            "`"$IssFile`""
        )
        
        # Eliminado el "&" problemático. Solo pasamos la ruta entre comillas.
        Invoke-ExternalCommand -Command "`"$Compiler`"" -Arguments ($InstallerArgs -join " ") -ErrorMessage "Falló la compilación de Inno Setup."
        
        return Join-Path -Path $ReleasesDir -ChildPath "RDWeb-Portal-Installer-Inno-$Version.exe"
    } 
    else {
        $nsisPaths = @(
            "${env:ProgramFiles(x86)}\NSIS\makensis.exe", 
            "$env:ProgramFiles\NSIS\makensis.exe"
        )
        $Compiler = $nsisPaths | Where-Object { Test-Path -Path $_ } | Select-Object -First 1
        
        if (-not $Compiler) { $Compiler = (Get-Command makensis.exe -ErrorAction SilentlyContinue).Source }
        if (-not $Compiler) { throw "No se encontró NSIS (makensis.exe)." }

        $NsiFileSource = Join-Path -Path $ProjectRoot -ChildPath "installer.nsi"
        $NsiFileTemp   = Join-Path -Path $ReleaseDir -ChildPath "installer.nsi"
        Copy-Item -Path $NsiFileSource -Destination $NsiFileTemp -Force
        
        $ExeFile = Join-Path -Path $ReleasesDir -ChildPath "RDWeb-Portal-Installer-$Version.exe"
        
        Set-Location -Path $ReleaseDir
        $InstallerArgs = @(
            "/DMyAppVersion=`"$Version`"",
            "/DBackendType=`"$BackType`"",
            "/DOutFileExe=`"$ExeFile`"",
            "`"installer.nsi`""
        )
        
        # Eliminado el "&" problemático. Solo pasamos la ruta entre comillas.
        Invoke-ExternalCommand -Command "`"$Compiler`"" -Arguments ($InstallerArgs -join " ") -ErrorMessage "Falló la compilación de NSIS."
        
        return $ExeFile
    }
}

# ---------------------------------------------------------------------
# Ejecución Principal
# ---------------------------------------------------------------------
try {
    Write-Information "========================================================"
    Write-Information " Iniciando Construcción: Backend [$BackendType] | Instalador [$InstallerType]"
    Write-Information "========================================================"

    Clear-BuildEnvironment
    Invoke-BuildFrontendWebApp
    Invoke-BuildBackendApp -Type $BackendType
    Publish-ReleaseArtifacts -Type $BackendType
    $ExePath = New-InstallerPackage -InstType $InstallerType -BackType $BackendType -Version $AppVersion

    # Limpieza final
    Set-Location -Path $ProjectRoot
    Remove-Item -Path $ReleaseDir -Recurse -Force

    $ResultInfo = [PSCustomObject]@{
        Status        = "Completado con Éxito"
        Backend       = $BackendType
        InstallerType = $InstallerType
        Version       = $AppVersion
        ZipArtifact   = $ZipFile
        ExeArtifact   = $ExePath
    }

    Write-Information "`n========================================================"
    Write-Information " CONSTRUCCIÓN COMPLETADA"
    Write-Information "========================================================"
    
    # Retornamos el resultado como un objeto estructurado al pipeline
    $ResultInfo

}
catch {
    Write-Error "Ocurrió un error crítico durante el proceso de empaquetado:`n$($_.Exception.Message)"
    # En un entorno CI/CD, asegurar que el script termine con un código de error
    exit 1
}
finally {
    # Restaurar la ubicación original sin importar lo que pase
    Set-Location -Path $ProjectRoot
}