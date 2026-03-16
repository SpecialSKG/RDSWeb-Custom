<#
.SYNOPSIS
    Instala y configura los prerrequisitos de IIS (URL Rewrite 2.1 y ARR 3.0).

.DESCRIPTION
    Este script automatiza la instalación de los módulos de IIS necesarios para 
    el Portal RDS Web. Verifica si los módulos ya están instalados mediante la 
    existencia de sus DLLs, ejecuta los instaladores MSI de forma silenciosa, 
    habilita el Proxy Inverso a nivel de servidor y reinicia IIS de forma segura.

.PARAMETER PrereqsDir
    Directorio donde se encuentran los instaladores MSI (rewrite_amd64_es-ES.msi 
    y requestRouter_amd64.msi).

.PARAMETER LogFile
    Ruta para almacenar el transcript de la ejecución del script.

.EXAMPLE
    .\setup-iis-prereqs.ps1 -PrereqsDir "C:\App\Prereqs" -LogFile "C:\logs\iis-prereqs.log"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path $_ -PathType Container })]
    [string]$PrereqsDir,

    [Parameter(Mandatory = $true)]
    [string]$LogFile
)

$ErrorActionPreference = 'Stop'
$WarningPreference = 'Continue'
$InformationPreference = 'Continue'

# =====================================================================
# Funciones Auxiliares (Helpers)
# =====================================================================

function Install-IisModule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$ModuleName,
        [Parameter(Mandatory = $true)][string]$MsiFileName,
        [Parameter(Mandatory = $true)][string]$ValidationDllPath
    )

    if (Test-Path -Path $ValidationDllPath) {
        Write-Information "[$ModuleName] ya se encuentra instalado. Omitiendo instalación."
        return
    }

    $msiPath = Join-Path -Path $PrereqsDir -ChildPath $MsiFileName
    
    if (-not (Test-Path -Path $msiPath)) {
        throw "No se encontró el instalador MSI para $ModuleName en la ruta: $msiPath"
    }

    Write-Information "Instalando $ModuleName..."
    $argumentList = @('/i', "`"$msiPath`"", '/qn', '/norestart')
    
    $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $argumentList -Wait -NoNewWindow -PassThru
    
    # 0 = Éxito, 3010 = Éxito (Requiere reinicio)
    if ($process.ExitCode -notin @(0, 3010)) {
        throw "La instalación de $ModuleName falló con el código de salida $($process.ExitCode)."
    }
    
    Write-Information "[$ModuleName] instalado correctamente."
}

# =====================================================================
# Flujo Principal
# =====================================================================

Start-Transcript -Path $LogFile -Force -Append:$false | Out-Null
Write-Information "Iniciando configuración de prerrequisitos de IIS..."

try {
    # ── 1. Definición de Rutas Clave ─────────────────────────────────
    $inetsrvDir = Join-Path -Path $env:windir -ChildPath "System32\inetsrv"
    $rewriteDll = Join-Path -Path $inetsrvDir -ChildPath "rewrite.dll"
    $arrDll = Join-Path -Path $inetsrvDir -ChildPath "requestRouter.dll"
    $appCmdExe = Join-Path -Path $inetsrvDir -ChildPath "appcmd.exe"

    # ── 2. Instalación de Módulos (DRY: Reutilización de lógica) ─────
    Install-IisModule -ModuleName "IIS URL Rewrite 2.1" `
        -MsiFileName "rewrite_amd64_es-ES.msi" `
        -ValidationDllPath $rewriteDll

    Install-IisModule -ModuleName "Application Request Routing (ARR) 3.0" `
        -MsiFileName "requestRouter_amd64.msi" `
        -ValidationDllPath $arrDll

    # ── 3. Habilitar Proxy Inverso ───────────────────────────────────
    if (Test-Path -Path $appCmdExe) {
        Write-Information "Habilitando Proxy Inverso global en IIS..."
        $appCmdArgs = @('set', 'config', '-section:system.webServer/proxy', '/enabled:"True"', '/commit:apphost')
        
        & $appCmdExe $appCmdArgs
        if ($LASTEXITCODE -ne 0) {
            throw "appcmd.exe falló al intentar habilitar el proxy inverso (Exit Code: $LASTEXITCODE)."
        }
        Write-Information "Proxy Inverso habilitado exitosamente."
    }
    else {
        Write-Warning "El ejecutable appcmd.exe no fue encontrado en $inetsrvDir. Asegúrese de que IIS esté instalado correctamente."
    }

    # ── 4. Reinicio de Servicios de IIS ──────────────────────────────
    Write-Information "Reiniciando los servicios de IIS para cargar los nuevos módulos..."
    
    # Preferimos el comando nativo de PowerShell si está disponible, sino fallback a iisreset
    if (Get-Service -Name W3SVC -ErrorAction SilentlyContinue) {
        Restart-Service -Name W3SVC, WAS -Force -ErrorAction Stop
        Write-Information "Servicios W3SVC y WAS reiniciados correctamente vía PowerShell."
    }
    else {
        Write-Verbose "Servicio W3SVC no detectado en Get-Service, usando iisreset tradicional..."
        & "iisreset.exe" /noforce
        if ($LASTEXITCODE -ne 0) {
            throw "El reinicio de IIS (iisreset) falló con el código $LASTEXITCODE."
        }
        Write-Information "IIS reiniciado correctamente."
    }

    Write-Information "Configuración de prerrequisitos finalizada con éxito."
}
catch {
    Write-Error "Fallo crítico durante la configuración de IIS: $($_.Exception.Message)"
    Stop-Transcript | Out-Null
    exit 1
}

Stop-Transcript | Out-Null
exit 0