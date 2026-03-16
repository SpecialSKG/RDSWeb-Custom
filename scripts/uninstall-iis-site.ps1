<#
.SYNOPSIS
    Desinstala el Sitio IIS y su Application Pool asociado para el Portal RDS Web.

.DESCRIPTION
    Este script es invocado por la rutina de desinstalación de Inno Setup. 
    Se encarga de limpiar de manera segura el sitio web creado en IIS, 
    su Application Pool asociado, y de intentar restaurar el estado del 
    "Default Web Site" si este había sido detenido durante la instalación.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$SiteName
)

$ErrorActionPreference = 'Stop'
$WarningPreference = 'Continue'
$InformationPreference = 'Continue'

Write-Information "Iniciando desinstalación del sitio IIS: $SiteName..."

try {
    # ── 0. Cargar Módulo IIS ─────────────────────────────────────────
    try {
        Import-Module WebAdministration -ErrorAction Stop
    }
    catch {
        # Si el administrador desinstaló el rol de IIS antes de correr nuestro
        # desinstalador, evitamos que el script falle abruptamente.
        Write-Warning "El módulo WebAdministration no está disponible. Es posible que el rol IIS ya haya sido removido del servidor. Omitiendo limpieza."
        exit 0
    }

    # ── 1. Eliminar Sitio IIS ────────────────────────────────────────
    $site = Get-Website -Name $SiteName -ErrorAction SilentlyContinue
    
    if ($null -ne $site) {
        Write-Information "Sitio IIS '$SiteName' detectado. Procediendo a limpiar..."
        
        # Solo intentamos detenerlo si realmente está en ejecución
        if ($site.State -eq 'Started') {
            Write-Verbose "Deteniendo el sitio '$SiteName'..."
            Stop-Website -Name $SiteName -ErrorAction Stop
            
            # Margen prudencial para que IIS libere los bloqueos (locks) de los archivos
            Start-Sleep -Seconds 1 
        }

        Remove-Website -Name $SiteName -ErrorAction Stop
        Write-Information "Sitio '$SiteName' eliminado exitosamente."
    }
    else {
        Write-Information "El sitio '$SiteName' no existe. Nada que eliminar."
    }

    # ── 2. Eliminar Application Pool ─────────────────────────────────
    $poolName = ($SiteName -replace '[^a-zA-Z0-9]', '') + 'Pool'
    $poolPath = "IIS:\AppPools\$poolName"

    if (Test-Path -Path $poolPath) {
        Write-Information "Application Pool '$poolName' detectado. Procediendo a eliminar..."
        
        # Obtener el estado real del AppPool para evitar excepciones innecesarias
        $appPoolState = Get-WebAppPoolState -Name $poolName -ErrorAction SilentlyContinue
        if ($appPoolState -and $appPoolState.Value -eq 'Started') {
            Write-Verbose "Deteniendo el Application Pool '$poolName'..."
            Stop-WebAppPool -Name $poolName -ErrorAction Stop
            Start-Sleep -Seconds 1
        }

        Remove-WebAppPool -Name $poolName -ErrorAction Stop
        Write-Information "Application Pool '$poolName' eliminado exitosamente."
    }
    else {
        Write-Information "El Application Pool '$poolName' no existe. Nada que eliminar."
    }

    # ── 3. Restaurar Default Web Site ────────────────────────────────
    $defaultSite = Get-Website -Name "Default Web Site" -ErrorAction SilentlyContinue
    if ($null -ne $defaultSite -and $defaultSite.State -ne 'Started') {
        Write-Information "Intentando reiniciar 'Default Web Site'..."
        try {
            Start-Website -Name "Default Web Site" -ErrorAction Stop
            Write-Information "'Default Web Site' reiniciado correctamente."
        }
        catch {
            # Lo tratamos como un Warning y no como Stop, ya que es probable que el puerto 80/443
            # esté ahora ocupado por otra aplicación instalada por el administrador.
            Write-Warning "No se pudo iniciar 'Default Web Site' automáticamente. Es posible que existan conflictos de puertos: $($_.Exception.Message)"
        }
    }

    Write-Information "Limpieza de configuración IIS completada con éxito."
    exit 0
}
catch {
    Write-Error "Fallo crítico durante la desinstalación en IIS: $($_.Exception.Message)"
    Write-Verbose "Stack Trace:`n$($_.ScriptStackTrace)"
    exit 1
}