<#
.SYNOPSIS
    Desinstala el Servicio Backend (NSSM) del Portal RDS Web.

.DESCRIPTION
    Este script es invocado por la rutina de desinstalación de Inno Setup. 
    Se encarga de verificar el estado del servicio, detenerlo de forma segura 
    si está en ejecución, y eliminar su registro del sistema. 
    Intenta utilizar NSSM como método principal y tiene un mecanismo de 
    respaldo (fallback) nativo utilizando sc.exe.

.PARAMETER BackendDir
    Directorio donde se encuentra (o encontraba) el ejecutable nssm.exe.
    
.PARAMETER ServiceName
    Nombre del servicio de Windows a eliminar.
#>

[CmdletBinding()]
param(
    # Nota: No usamos [ValidateScript({Test-Path $_})] aquí porque durante 
    # una desinstalación es posible que la carpeta ya haya sido parcialmente eliminada.
    [Parameter(Mandatory = $true)]
    [string]$BackendDir,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ServiceName
)

$ErrorActionPreference = 'Stop'
$WarningPreference = 'Continue'
$InformationPreference = 'Continue'

Write-Information "Iniciando proceso de desinstalación para el servicio: $ServiceName"

try {
    # ── 1. Verificar existencia del servicio ─────────────────────────
    $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    
    if ($null -eq $service) {
        Write-Information "El servicio '$ServiceName' no existe en el sistema. Nada que eliminar."
        exit 0
    }

    Write-Information "Servicio '$ServiceName' detectado. Procediendo con la limpieza..."

    # ── 2. Detener el servicio de forma segura ───────────────────────
    if ($service.Status -ne 'Stopped') {
        Write-Information "Deteniendo el servicio '$ServiceName'..."
        Stop-Service -Name $ServiceName -Force -ErrorAction Stop
        
        # Le damos un margen al OS para liberar los handles (archivos bloqueados)
        Start-Sleep -Seconds 3 
    }
    else {
        Write-Information "El servicio ya se encuentra detenido."
    }

    # ── 3. Eliminación del Servicio (NSSM o Fallback) ────────────────
    $nssmExe = Join-Path -Path $BackendDir -ChildPath "nssm.exe"

    if (Test-Path -Path $nssmExe -PathType Leaf) {
        Write-Information "Ejecutable NSSM detectado. Eliminando servicio vía NSSM..."
        $nssmArgs = @('remove', $ServiceName, 'confirm')
        
        & $nssmExe $nssmArgs
        
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "NSSM finalizó con código $LASTEXITCODE. Es posible que el servicio ya estuviera marcado para eliminación."
        }
    }
    else {
        Write-Warning "Ejecutable nssm.exe no encontrado en la ruta. Usando la utilidad nativa sc.exe como fallback..."
        
        # Se usa 'sc.exe' explícitamente para no confundirlo con el alias 'sc' (Set-Content) de PowerShell
        $scArgs = @('delete', $ServiceName)
        & "sc.exe" $scArgs
        
        # 1060 = ERROR_SERVICE_DOES_NOT_EXIST (Lo ignoramos si ya no existe)
        if ($LASTEXITCODE -notin @(0, 1060)) {
            Write-Warning "sc.exe finalizó con código de salida $LASTEXITCODE."
        }
    }

    Start-Sleep -Seconds 1
    Write-Information "Proceso de eliminación del servicio completado."
    exit 0
}
catch {
    Write-Error "Ocurrió un error crítico al intentar desinstalar el servicio '$ServiceName': $($_.Exception.Message)"
    Write-Verbose "Stack Trace:`n$($_.ScriptStackTrace)"
    # En desinstaladores a veces se prefiere devolver 0 para no frenar la limpieza completa, 
    # pero devolver 1 permite a Inno Setup registrar el error si está configurado para ello.
    exit 1
}