# =====================================================================
# Desinstalación del Servicio Backend (NSSM)
# Llamado por el desinstalador de Inno Setup — NO ejecutar manualmente
# =====================================================================
param(
    [Parameter(Mandatory)][string]$BackendDir,
    [Parameter(Mandatory)][string]$ServiceName
)

$ErrorActionPreference = "SilentlyContinue"
$NssmExe = "$BackendDir\nssm.exe"

if (Get-Service -Name $ServiceName -ErrorAction SilentlyContinue) {
    Write-Host "Deteniendo servicio '$ServiceName'..."
    Stop-Service -Name $ServiceName -Force
    Start-Sleep -Seconds 3

    if (Test-Path $NssmExe) {
        Write-Host "Eliminando servicio '$ServiceName' via NSSM..."
        & $NssmExe remove $ServiceName confirm
    }
    else {
        # Fallback: usar sc.exe si nssm no está disponible
        Write-Host "nssm.exe no encontrado - usando sc.exe como fallback..."
        sc.exe delete $ServiceName
    }

    Start-Sleep -Seconds 1
    Write-Host "Servicio eliminado."
}
else {
    Write-Host "Servicio '$ServiceName' no encontrado - nada que eliminar."
}

exit 0
