# =====================================================================
# Desinstalación del Sitio IIS — Portal RD Web
# Llamado por el desinstalador de Inno Setup — NO ejecutar manualmente
# =====================================================================
param(
    [Parameter(Mandatory)][string]$SiteName
)

$ErrorActionPreference = "SilentlyContinue"

Import-Module WebAdministration -ErrorAction SilentlyContinue

# ── 1. Detener y eliminar sitio IIS ─────────────────────────────────
if (Get-Website -Name $SiteName -ErrorAction SilentlyContinue) {
    Write-Host "Deteniendo sitio IIS '$SiteName'..."
    Stop-Website -Name $SiteName -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1

    Write-Host "Eliminando sitio IIS '$SiteName'..."
    Remove-Website -Name $SiteName -ErrorAction SilentlyContinue
    Write-Host "Sitio eliminado."
}
else {
    Write-Host "Sitio '$SiteName' no encontrado — nada que eliminar."
}

# ── 2. Eliminar Application Pool ────────────────────────────────────
$PoolName = ($SiteName -replace '[^a-zA-Z0-9]', '') + "Pool"

if (Test-Path "IIS:\AppPools\$PoolName") {
    Write-Host "Deteniendo Application Pool '$PoolName'..."
    Stop-WebAppPool -Name $PoolName -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1

    Write-Host "Eliminando Application Pool '$PoolName'..."
    Remove-WebAppPool -Name $PoolName -ErrorAction SilentlyContinue
    Write-Host "Application Pool eliminado."
}
else {
    Write-Host "Application Pool '$PoolName' no encontrado — nada que eliminar."
}

# ── 3. Reiniciar Default Web Site si existe ──────────────────────────
$DefaultSite = Get-Website -Name "Default Web Site" -ErrorAction SilentlyContinue
if ($DefaultSite -and $DefaultSite.State -ne 'Started') {
    Write-Host "Reiniciando 'Default Web Site'..."
    Start-Website -Name "Default Web Site" -ErrorAction SilentlyContinue
}

Write-Host "Limpieza IIS completada."
exit 0
