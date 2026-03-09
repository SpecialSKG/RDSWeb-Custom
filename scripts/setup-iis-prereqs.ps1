# =====================================================================
# Configuración de Prerrequisitos IIS  (URL Rewrite 2.1 + ARR 3.0)
# Llamado por el instalador de Inno Setup — NO ejecutar manualmente
# =====================================================================
param(
    [Parameter(Mandatory)][string]$PrereqsDir,
    [Parameter(Mandatory)][string]$LogFile
)

$ErrorActionPreference = "Stop"
Start-Transcript -Path $LogFile -Force

try {
    $RewriteDll = "$env:windir\System32\inetsrv\rewrite.dll"
    $ArrDll     = "$env:windir\System32\inetsrv\requestRouter.dll"
    $AppCmd     = "$env:windir\System32\inetsrv\appcmd.exe"

    # ── 1. URL Rewrite 2.1 ──────────────────────────────────────────
    if (-not (Test-Path $RewriteDll)) {
        Write-Host "Instalando IIS URL Rewrite 2.1..."
        $msi = "$PrereqsDir\rewrite_amd64_es-ES.msi"
        if (-not (Test-Path $msi)) { throw "No se encontró el instalador: $msi" }

        $p = Start-Process msiexec.exe -ArgumentList "/i `"$msi`" /qn /norestart" `
             -Wait -NoNewWindow -PassThru
        if ($p.ExitCode -notin @(0, 3010)) {
            throw "URL Rewrite falló con exit code $($p.ExitCode)"
        }
        Write-Host "URL Rewrite 2.1 instalado correctamente."
    }
    else {
        Write-Host "URL Rewrite ya está instalado — omitiendo."
    }

    # ── 2. Application Request Routing (ARR) 3.0 ────────────────────
    if (-not (Test-Path $ArrDll)) {
        Write-Host "Instalando Application Request Routing 3.0..."
        $msi = "$PrereqsDir\requestRouter_amd64.msi"
        if (-not (Test-Path $msi)) { throw "No se encontró el instalador: $msi" }

        $p = Start-Process msiexec.exe -ArgumentList "/i `"$msi`" /qn /norestart" `
             -Wait -NoNewWindow -PassThru
        if ($p.ExitCode -notin @(0, 3010)) {
            throw "ARR falló con exit code $($p.ExitCode)"
        }
        Write-Host "ARR 3.0 instalado correctamente."
    }
    else {
        Write-Host "ARR 3.0 ya está instalado — omitiendo."
    }

    # ── 3. Habilitar Proxy Inverso (viene apagado por defecto) ──────
    if (Test-Path $AppCmd) {
        Write-Host "Habilitando Proxy Inverso en IIS..."
        & $AppCmd set config -section:system.webServer/proxy /enabled:"True" /commit:apphost 2>&1 | Out-Null
        Write-Host "Proxy Inverso habilitado."
    }
    else {
        Write-Host "[ADVERTENCIA] appcmd.exe no encontrado — verificar IIS." -ForegroundColor Yellow
    }

    # ── 4. Reiniciar IIS para cargar los módulos recién instalados ──
    Write-Host "Reiniciando IIS..."
    & iisreset /noforce 2>&1 | Out-Null
    Write-Host "IIS reiniciado correctamente."

    Stop-Transcript
    exit 0
}
catch {
    Write-Host "ERROR: $($_.Exception.Message)"
    Stop-Transcript
    exit 1
}
