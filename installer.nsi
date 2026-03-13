; =====================================================================
; Instalador NSIS - Portal RD Web (Versión Final Completa)
; =====================================================================

!include "MUI2.nsh"
!include "LogicLib.nsh"
!include "WordFunc.nsh"

; =====================================================================
; DEFINICIONES GENERALES
; =====================================================================
!define MyAppName "Portal RDS Web"
!define MyAppPublisher "MH-DINAFI-USC"
!define ServiceName "RDSWeb"

; Validamos si la versión viene inyectada desde build.ps1
!ifndef MyAppVersion
  !define MyAppVersion "1.0.0"
!endif

; Validamos si el backend viene inyectado desde build.ps1
!ifndef BackendType
  !define BackendType "express"
!endif

; =====================================================================
; VARIABLES GLOBALES
; =====================================================================
Var Dialog
; -- Credenciales --
Var LblCredUser
Var TxtCredPass
Var ValCredPass
; -- Certificados --
Var CmbCert
Var TxtHost
Var ValHost
Var ValCertThumbprint
; -- Active Directory y Servidores --
Var TxtAdLdap
Var TxtAdBaseDn
Var TxtAdDomain
Var TxtAdUser
Var TxtAdPass
Var TxtSrvRdcb
Var ValAdLdap
Var ValAdBaseDn
Var ValAdDomain
Var ValAdUser
Var ValAdPass
Var ValSrvRdcb

; =====================================================================
; CONFIGURACIÓN DEL INSTALADOR
; =====================================================================
Name "${MyAppName}"
!ifndef OutFileExe
  !define OutFileExe "RDWeb-Portal-Installer.exe"
!endif
OutFile "${OutFileExe}"
InstallDir "C:\inetpub\wwwroot"
RequestExecutionLevel admin
ShowInstDetails show
ShowUninstDetails show

!define MUI_ICON "assets\installer\app-icon.ico"
!define MUI_UNICON "assets\installer\app-icon.ico"
!define MUI_WELCOMEFINISHPAGE_BITMAP "assets\installer\wizard-banner.bmp"

; =====================================================================
; ORDEN DE LAS PÁGINAS DEL ASISTENTE
; =====================================================================
!insertmacro MUI_PAGE_WELCOME

; 1. Custom: Credenciales
Page custom PageCredentialsCreate PageCredentialsLeave
; 2. Custom: Active Directory
Page custom PageADCreate PageADLeave
; 3. Custom: Certificados
Page custom PageCertCreate PageCertLeave

; Use components page without description box (more width for component names)
!define MUI_COMPONENTSPAGE_NODESC

!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

; Páginas de Desinstalación
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

; Idioma
!insertmacro MUI_LANGUAGE "Spanish"
!insertmacro MUI_LANGUAGE "English"


; =====================================================================
; LÓGICA: PÁGINA DE CREDENCIALES
; =====================================================================
Function PageCredentialsCreate
    !insertmacro MUI_HEADER_TEXT "Credenciales del Servicio" "El servicio backend se ejecutará bajo la cuenta de dominio indicada abajo.$\r$\nIngrese la contraseña para configurar el servicio."
    nsDialogs::Create 1018
    Pop $Dialog
    ${If} $Dialog == error
        Abort
    ${EndIf}

    ReadEnvStr $0 "USERDOMAIN"
    ReadEnvStr $1 "USERNAME"
    StrCpy $2 "$0\$1"

    ${NSD_CreateLabel} 0 10u 100% 12u "Cuenta de servicio: $2"
    Pop $LblCredUser
    ${NSD_CreateLabel} 0 30u 100% 12u "Contraseña:"
    Pop $0
    ${NSD_CreatePassword} 0 42u 100% 12u ""
    Pop $TxtCredPass

    nsDialogs::Show
FunctionEnd

Function PageCredentialsLeave
    ${NSD_GetText} $TxtCredPass $ValCredPass
    ${If} $ValCredPass == ""
        MessageBox MB_ICONSTOP|MB_OK "Debe ingresar la contraseña de la cuenta de servicio."
        Abort
    ${EndIf}

    InitPluginsDir 
    FileOpen $0 "$PLUGINSDIR\svcpwd_validate.dat" w
    FileWrite $0 $ValCredPass
    FileClose $0

    FileOpen $0 "$PLUGINSDIR\validate-creds.ps1" w
    FileWrite $0 "try {$\r$\n"
    FileWrite $0 "  $$pw = (Get-Content '$PLUGINSDIR\svcpwd_validate.dat' -Raw).Trim()$\r$\n"
    FileWrite $0 "  Add-Type -AssemblyName System.DirectoryServices.AccountManagement$\r$\n"
    FileWrite $0 "  $$c = [System.DirectoryServices.AccountManagement.PrincipalContext]::new([System.DirectoryServices.AccountManagement.ContextType]::Domain, $$env:USERDNSDOMAIN)$\r$\n"
    FileWrite $0 "  if ($$c.ValidateCredentials($$env:USERNAME, $$pw)) { exit 0 } else { exit 1 }$\r$\n"
    FileWrite $0 "} catch { exit 2 }$\r$\n"
    FileClose $0

    nsExec::Exec 'powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -NoProfile -File "$PLUGINSDIR\validate-creds.ps1"'
    Pop $0

    Delete "$PLUGINSDIR\svcpwd_validate.dat"
    Delete "$PLUGINSDIR\validate-creds.ps1"

    ${If} $0 == 1
        MessageBox MB_ICONSTOP|MB_OK "La contraseña ingresada no es válida para la cuenta de servicio.$\r$\n$\r$\nPor favor, verifique e intente de nuevo."
        Abort
    ${ElseIf} $0 == 2
        MessageBox MB_ICONINFORMATION|MB_OK "No se pudo validar la contraseña contra el dominio.$\r$\nLa instalación continuará, pero si la contraseña es incorrecta el servicio no podrá iniciar."
    ${EndIf}
FunctionEnd


; =====================================================================
; LÓGICA: PÁGINA DE ACTIVE DIRECTORY
; =====================================================================
Function PageADCreate
    !insertmacro MUI_HEADER_TEXT "Configuración de Active Directory y Servidores" "Configure la conexión LDAP al controlador de dominio y los servidores del portal."
    nsDialogs::Create 1018
    Pop $Dialog
    ${If} $Dialog == error
        Abort
    ${EndIf}

    InitPluginsDir
    FileOpen $0 "$PLUGINSDIR\detect-ad.ps1" w
    FileWrite $0 "$$d = $$env:USERDNSDOMAIN; if($$d) { $$base = ($$d -split '\.' | ForEach-Object { 'DC=' + $$_ }) -join ','; Write-Output $$base } else { Write-Output '' }$\r$\n"
    FileClose $0
    nsExec::ExecToStack 'powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -NoProfile -File "$PLUGINSDIR\detect-ad.ps1"'
    Pop $0
    Pop $1
    ${WordFind} "$1" "$\r$\n" "-1{" $1 

    ${NSD_CreateLabel} 0 0u 100% 10u "URL LDAP del Domain Controller:"
    Pop $0
    ReadEnvStr $2 "LOGONSERVER"
    ReadEnvStr $3 "USERDNSDOMAIN"
    ${WordFind} "$2" "\" "-1" $2 
    ${NSD_CreateText} 0 10u 100% 12u "ldap://$2.$3"
    Pop $TxtAdLdap

    ${NSD_CreateLabel} 0 25u 100% 10u "Base DN del dominio:"
    Pop $0
    ${NSD_CreateText} 0 35u 100% 12u "$1"
    Pop $TxtAdBaseDn

    ${NSD_CreateLabel} 0 50u 100% 10u "Dominio NetBIOS:"
    Pop $0
    ReadEnvStr $4 "USERDOMAIN"
    ${NSD_CreateText} 0 60u 100% 12u "$4"
    Pop $TxtAdDomain

    ${NSD_CreateLabel} 0 75u 48% 10u "Cuenta servicio (UPN):"
    Pop $0
    ${NSD_CreateText} 0 85u 48% 12u ""
    Pop $TxtAdUser

    ${NSD_CreateLabel} 52% 75u 48% 10u "Contraseña AD:"
    Pop $0
    ${NSD_CreatePassword} 52% 85u 48% 12u ""
    Pop $TxtAdPass

    ${NSD_CreateLabel} 0 105u 100% 10u "Servidor RD Connection Broker:"
    Pop $0
    ${NSD_CreateText} 0 115u 100% 12u ""
    Pop $TxtSrvRdcb

    nsDialogs::Show
FunctionEnd

Function PageADLeave
    ${NSD_GetText} $TxtAdLdap $ValAdLdap
    ${NSD_GetText} $TxtAdBaseDn $ValAdBaseDn
    ${NSD_GetText} $TxtAdDomain $ValAdDomain
    ${NSD_GetText} $TxtAdUser $ValAdUser
    ${NSD_GetText} $TxtAdPass $ValAdPass
    ${NSD_GetText} $TxtSrvRdcb $ValSrvRdcb

    ${If} $ValAdLdap == ""
    ${OrIf} $ValAdBaseDn == ""
    ${OrIf} $ValAdDomain == ""
    ${OrIf} $ValAdUser == ""
    ${OrIf} $ValAdPass == ""
        MessageBox MB_ICONSTOP|MB_OK "Todos los campos de Active Directory son obligatorios."
        Abort
    ${EndIf}

    ${If} $ValSrvRdcb == ""
        MessageBox MB_ICONSTOP|MB_OK "Debe ingresar el servidor RD Connection Broker."
        Abort
    ${EndIf}
FunctionEnd


; =====================================================================
; LÓGICA: PÁGINA DE CERTIFICADO SSL
; =====================================================================
Function PageCertCreate
    !insertmacro MUI_HEADER_TEXT "Certificado SSL" "Seleccione el certificado SSL que se usará para el sitio HTTPS del portal.$\r$\nSolo se muestran certificados válidos con clave privada."
    nsDialogs::Create 1018
    Pop $Dialog
    ${If} $Dialog == error
        Abort
    ${EndIf}

    ${NSD_CreateLabel} 0 10u 100% 12u "Certificado:"
    Pop $0
    ${NSD_CreateDropList} 0 25u 100% 12u ""
    Pop $CmbCert

    ${NSD_CreateLabel} 0 50u 100% 12u "Nombre de host (FQDN):"
    Pop $0

    ReadEnvStr $0 "COMPUTERNAME"
    ReadEnvStr $1 "USERDNSDOMAIN"
    ${If} $1 != ""
        StrCpy $2 "$0.$1"
    ${Else}
        StrCpy $2 "$0"
    ${EndIf}
    ${NSD_CreateText} 0 65u 100% 12u "$2"
    Pop $TxtHost

    InitPluginsDir
    FileOpen $0 "$PLUGINSDIR\enum-certs.ps1" w
    FileWrite $0 "$$certs = Get-ChildItem Cert:\LocalMachine\My | Where-Object { $$_.HasPrivateKey -and $$_.NotAfter -gt (Get-Date) } | ForEach-Object { $$_.Subject + ' (exp: ' + $$_.NotAfter.ToString('yyyy-MM-dd') + ')' }$\r$\n"
    FileWrite $0 "[System.IO.File]::WriteAllLines('$PLUGINSDIR\\certs_list.txt', $$certs, (New-Object System.Text.UTF8Encoding($$false)))$\r$\n"
    FileClose $0

    nsExec::Exec 'powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -NoProfile -File "$PLUGINSDIR\enum-certs.ps1"'

    ClearErrors
    FileOpen $0 "$PLUGINSDIR\certs_list.txt" r
    ${If} $0 != ""
        loop_read_certs:
            FileRead $0 $1
            IfErrors done_read_certs
            StrLen $2 $1
            IntOp $2 $2 - 2
            StrCpy $1 $1 $2
            ${If} $1 != ""
                ${NSD_CB_AddString} $CmbCert $1
            ${EndIf}
            Goto loop_read_certs
        done_read_certs:
        FileClose $0
        SendMessage $CmbCert ${CB_SETCURSEL} 0 0
    ${Else}
        ${NSD_CB_AddString} $CmbCert "No se encontraron certificados válidos."
        SendMessage $CmbCert ${CB_SETCURSEL} 0 0
    ${EndIf}

    nsDialogs::Show
FunctionEnd

Function PageCertLeave
    ${NSD_GetText} $TxtHost $ValHost
    ${If} $ValHost == ""
        MessageBox MB_ICONSTOP|MB_OK "Debe ingresar el nombre de host del sitio (ej: portal.midominio.com)."
        Abort
    ${EndIf}

    ${NSD_GetText} $CmbCert $0
    ${If} $0 == ""
    ${OrIf} $0 == "No se encontraron certificados válidos."
        MessageBox MB_ICONSTOP|MB_OK "Debe seleccionar un certificado SSL válido para continuar."
        Abort
    ${EndIf}

    ${WordFind} "$0" "[" "+2" $ValCertThumbprint
    ${WordFind} "$ValCertThumbprint" "]" "+1" $ValCertThumbprint
FunctionEnd


; =====================================================================
; COMPONENTES / SECCIONES
; =====================================================================

Section "Prerrequisitos IIS (URL Rewrite 2.1 y ARR 3.0)" SEC_PREREQS
    ; 1. Extraer scripts de instalacion a carpeta temporal
    SetOutPath "$TEMP"
    File "scripts\setup-iis-prereqs.ps1"
    File "scripts\setup-backend-service.ps1"
    File "scripts\setup-iis-site.ps1"

    ; 2. Extraer prerrequisitos (MSIs) a carpeta temporal
    SetOutPath "$TEMP\prereqs"
    File /r "prereqs\*"

    ; 3. Ejecutar script de prerrequisitos
    CreateDirectory "$INSTDIR\backend\logs"
    DetailPrint "Instalando prerrequisitos de IIS..."
    nsExec::ExecToLog '"$WINDIR\Sysnative\WindowsPowerShell\v1.0\powershell.exe" -ExecutionPolicy Bypass -NoProfile -File "$TEMP\setup-iis-prereqs.ps1" -PrereqsDir "$TEMP\prereqs" -LogFile "$INSTDIR\backend\logs\install-prereqs.log"'
    Pop $0
    ${If} $0 != 0
        MessageBox MB_ICONSTOP|MB_OK "Ocurrieron errores al instalar prerrequisitos de IIS.$\r$\nRevise el log en: $INSTDIR\backend\logs\install-prereqs.log"
    ${EndIf}
SectionEnd


Section "Backend ${BackendType} (API + Servicio Windows)" SEC_BACKEND
    ; Detener servicio y procesos previos para evitar bloqueo de archivos
    DetailPrint "Deteniendo servicio/procesos existentes (si aplica)..."
    nsExec::ExecToLog '"$WINDIR\Sysnative\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -Command "if (Get-Service -Name \"${ServiceName}\" -ErrorAction SilentlyContinue) { Stop-Service -Name \"${ServiceName}\" -Force -ErrorAction SilentlyContinue; Start-Sleep -Seconds 3 }"'
    Pop $0
    nsExec::ExecToLog 'taskkill /F /IM main.exe 2>NUL'
    Pop $0
    nsExec::ExecToLog 'taskkill /F /IM node.exe 2>NUL'
    Pop $0
    !if "${BackendType}" == "python"
        SetOutPath "$INSTDIR\backend"
        File "backend\main.exe"
        File "backend\nssm.exe"
    !else
        SetOutPath "$INSTDIR\backend\src"
        File /r "backend\src\*"
        SetOutPath "$INSTDIR\backend\node_modules"
        File /r "backend\node_modules\*"
        SetOutPath "$INSTDIR\backend"
        File "backend\package.json"
        File "backend\nssm.exe"
        File "backend\node.exe"
    !endif

    ; --- GENERAR EL ARCHIVO .ENV ---
    DetailPrint "Generando archivo .env..."
    InitPluginsDir
    FileOpen $0 "$PLUGINSDIR\gen-jwt.vbs" w
    FileWrite $0 'Randomize : Dim s, i : For i = 1 To 32 : s = s & Hex(Int((15 * Rnd) + 0)) : Next : WScript.StdOut.Write s'
    FileClose $0
    nsExec::ExecToStack 'cscript.exe //nologo "$PLUGINSDIR\gen-jwt.vbs"'
    Pop $0
    Pop $1

    FileOpen $0 "$INSTDIR\backend\.env" w
    FileWrite $0 "# ============================================================$\r$\n"
    FileWrite $0 "#  RDWeb Portal - Generado por el Instalador$\r$\n"
    FileWrite $0 "# ============================================================$\r$\n$\r$\n"
    FileWrite $0 "PORT=3000$\r$\n"
    FileWrite $0 "NODE_ENV=production$\r$\n$\r$\n"
    FileWrite $0 "JWT_SECRET=$1$\r$\n"
    FileWrite $0 "JWT_EXPIRES_IN=1h$\r$\n$\r$\n"
    FileWrite $0 "LDAP_URL=$ValAdLdap$\r$\n"
    FileWrite $0 "LDAP_BASE_DN=$ValAdBaseDn$\r$\n"
    FileWrite $0 "AD_DOMAIN=$ValAdDomain$\r$\n"
    FileWrite $0 "AD_SERVICE_USER=$ValAdUser$\r$\n"
    FileWrite $0 "AD_SERVICE_PASS=$ValAdPass$\r$\n$\r$\n"
    FileWrite $0 "RDCB_SERVER=$ValSrvRdcb$\r$\n$\r$\n"
    FileWrite $0 "RDP_GATEWAY_CREDENTIAL_SOURCE=0$\r$\n"
    FileWrite $0 "RDP_PROMPT_CREDENTIAL_ONCE=true$\r$\n"
    FileWrite $0 "RDP_PROMPT_FOR_CREDENTIALS_ON_CLIENT=true$\r$\n"
    FileWrite $0 "RDP_USE_MULTIMON=false$\r$\n"
    FileWrite $0 "RDP_SPAN_MONITORS=false$\r$\n$\r$\n"
    FileWrite $0 "SIMULATION_MODE=false$\r$\n"
    FileClose $0

    ; --- CONFIGURAR EL SERVICIO NSSM ---
    DetailPrint "Configurando servicio backend..."
    CreateDirectory "$INSTDIR\backend\logs"
    
    FileOpen $0 "$TEMP\svcpwd.dat" w
    FileWrite $0 $ValCredPass
    FileClose $0

    nsExec::ExecToLog '"$WINDIR\Sysnative\WindowsPowerShell\v1.0\powershell.exe" -ExecutionPolicy Bypass -NoProfile -File "$TEMP\setup-backend-service.ps1" -BackendDir "$INSTDIR\backend" -ServiceName "${ServiceName}" -BackendType "${BackendType}" -CredentialFile "$TEMP\svcpwd.dat" -LogFile "$INSTDIR\backend\logs\install-service.log"'
    Pop $0
    ${If} $0 != 0
        MessageBox MB_ICONSTOP|MB_OK "Ocurrieron errores al configurar el servicio backend.$\r$\nRevise el log en: $INSTDIR\backend\logs\install-service.log"
    ${EndIf}

    Delete "$TEMP\svcpwd.dat"
SectionEnd


Section "Frontend Angular (archivos estáticos IIS)" SEC_FRONTEND
    SetOutPath "$INSTDIR\frontend"
    File /r "frontend\*"

    DetailPrint "Configurando sitio IIS..."
    CreateDirectory "$INSTDIR\backend\logs"

    nsExec::ExecToLog '"$WINDIR\Sysnative\WindowsPowerShell\v1.0\powershell.exe" -ExecutionPolicy Bypass -NoProfile -File "$TEMP\setup-iis-site.ps1" -SiteName "${MyAppName}" -FrontendDir "$INSTDIR\frontend" -CertThumbprint "$ValCertThumbprint" -HostName "$ValHost" -LogFile "$INSTDIR\backend\logs\install-iis-site.log"'
    Pop $0
    ${If} $0 != 0
        MessageBox MB_ICONSTOP|MB_OK "Ocurrieron errores al configurar el sitio IIS.$\r$\nRevise el log en: $INSTDIR\backend\logs\install-iis-site.log"
    ${EndIf}

    ; --- Icono para desinstalador ---
    SetOutPath "$INSTDIR\assets\installer"
    File "assets\installer\app-icon.ico"

    ; --- Scripts de desinstalación (persisten) ---
    SetOutPath "$INSTDIR\scripts"
    File "scripts\uninstall-backend-service.ps1"
    File "scripts\uninstall-iis-site.ps1"

    WriteUninstaller "$INSTDIR\uninstall.exe"
    
    ; Registro en Agregar/Quitar Programas
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${MyAppName}" "DisplayName" "${MyAppName}"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${MyAppName}" "DisplayIcon" "$INSTDIR\assets\installer\app-icon.ico"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${MyAppName}" "UninstallString" "$\"$INSTDIR\uninstall.exe$\""
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${MyAppName}" "QuietUninstallString" "$\"$INSTDIR\uninstall.exe$\" /S"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${MyAppName}" "InstallLocation" "$\"$INSTDIR$\""
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${MyAppName}" "Publisher" "${MyAppPublisher}"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${MyAppName}" "DisplayVersion" "${MyAppVersion}"
    WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${MyAppName}" "NoModify" 1
    WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${MyAppName}" "NoRepair" 1
SectionEnd

; =====================================================================
; DESINSTALADOR
; =====================================================================
Section "Uninstall"
    DetailPrint "Deteniendo y eliminando sitio IIS..."
    nsExec::ExecToLog '"$WINDIR\Sysnative\WindowsPowerShell\v1.0\powershell.exe" -ExecutionPolicy Bypass -NoProfile -File "$INSTDIR\scripts\uninstall-iis-site.ps1" -SiteName "${MyAppName}"'
    
    DetailPrint "Deteniendo y eliminando servicio Backend..."
    nsExec::ExecToLog '"$WINDIR\Sysnative\WindowsPowerShell\v1.0\powershell.exe" -ExecutionPolicy Bypass -NoProfile -File "$INSTDIR\scripts\uninstall-backend-service.ps1" -BackendDir "$INSTDIR\backend" -ServiceName "${ServiceName}"'

    DetailPrint "Eliminando archivos..."
    RMDir /r "$INSTDIR\backend"
    RMDir /r "$INSTDIR\frontend"
    RMDir /r "$INSTDIR\scripts"
    Delete "$INSTDIR\uninstall.exe"
    RMDir "$INSTDIR" 

    DetailPrint "Limpiando registro..."
    DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${MyAppName}"
SectionEnd