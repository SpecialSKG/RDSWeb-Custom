; =====================================================================
; Instalador NSIS - Portal RD Web (Refactorizado y Mejorado)
; =====================================================================

!include "MUI2.nsh"
!include "LogicLib.nsh"
!include "WordFunc.nsh"

; =====================================================================
; DEFINICIONES GENERALES
; =====================================================================
Unicode true

!define MyAppName "Portal RDS Web"
!define MyAppPublisher "MH-DINAFI-USC"
!define ServiceName "RDSWeb"

!ifndef MyAppVersion
  !define MyAppVersion "0.0.0"
!endif

!ifndef BackendType
  !define BackendType "express"
!endif

; =====================================================================
; MACROS REUTILIZABLES
; =====================================================================
!macro ExecPowerShell ScriptPath Arguments
    Push $R0
    DetailPrint "Ejecutando: ${ScriptPath}..."
    nsExec::ExecToLog '"$WINDIR\Sysnative\WindowsPowerShell\v1.0\powershell.exe" -ExecutionPolicy Bypass -NoProfile -File "${ScriptPath}" ${Arguments}'
    Pop $R0
    ${If} $R0 != 0
        MessageBox MB_ICONSTOP|MB_OK "Fallo crítico al ejecutar: ${ScriptPath}$\r$\nCódigo de error: $R0.$\r$\nRevise los logs en la carpeta destino para más detalles."
        Abort "Instalación abortada por fallo en script externo."
    ${EndIf}
    Pop $R0
!macroend

!macro ExecPowerShellQuiet ScriptPath Arguments
    Push $R0
    DetailPrint "Desinstalando (Ejecutando script): ${ScriptPath}..."
    nsExec::ExecToLog '"$WINDIR\Sysnative\WindowsPowerShell\v1.0\powershell.exe" -ExecutionPolicy Bypass -NoProfile -File "${ScriptPath}" ${Arguments}'
    Pop $R0
    Pop $R0
!macroend

; =====================================================================
; VARIABLES GLOBALES
; =====================================================================
Var Dialog

; -- Certificados --
Var CmbCert
Var TxtHost
Var ValHost
Var ValCertThumbprint

; -- Active Directory y Servidores LDAP --
Var TxtLdapHost
Var TxtLdapPort
Var TxtAdBaseDn
Var TxtLdapUser
Var TxtLdapPass
Var TxtLdapSearchBase
Var TxtLdapSearchFilter
Var TxtSvcUser
Var TxtSvcPass
Var TxtSrvRdcb

Var ValLdapHost
Var ValLdapPort
Var ValAdBaseDn
Var ValLdapUser
Var ValLdapPass
Var ValLdapSearchBase
Var ValLdapSearchFilter
Var ValSvcUser
Var ValSvcPass
Var ValSrvRdcb

; =====================================================================
; CONFIGURACIÓN DEL INSTALADOR Y UI
; =====================================================================
Name "${MyAppName}"
!ifndef OutFileExe
    !define OutFileExe "RDWeb-Portal-Installer-${MyAppVersion}.exe"
!endif
OutFile "${OutFileExe}"
InstallDir "C:\inetpub\wwwroot"
RequestExecutionLevel admin
ShowInstDetails show
ShowUninstDetails show

!define MUI_ICON "assets\installer\app-icon.ico"
!define MUI_UNICON "assets\installer\app-icon.ico"
!define MUI_WELCOMEFINISHPAGE_BITMAP "assets\installer\wizard-banner.bmp"
!define MUI_COMPONENTSPAGE_NODESC

; -- Orden de Páginas --
!insertmacro MUI_PAGE_WELCOME
Page custom PageLDAPConnCreate PageLDAPConnLeave
Page custom PageLDAPCredsCreate PageLDAPCredsLeave
Page custom PageCertCreate PageCertLeave
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

; -- Páginas de Desinstalación --
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

; -- Idiomas --
!insertmacro MUI_LANGUAGE "Spanish"
!insertmacro MUI_LANGUAGE "English"

; =====================================================================
; LÓGICA: PÁGINA 1 - CONEXIÓN LDAP
; =====================================================================
Function PageLDAPConnCreate
    !insertmacro MUI_HEADER_TEXT "Configuración de Red LDAP" "Configure los parámetros de conexión al servidor de directorio."
    nsDialogs::Create 1018
    Pop $Dialog
    ${If} $Dialog == error
        Abort
    ${EndIf}

    ; --- Host y Puerto LDAP ---
    ${NSD_CreateLabel} 0 0u 70% 10u "Host LDAP (ej: SRV-DC.LAB-MH.LOCAL):"
    Pop $0
    ${NSD_CreateText} 0 10u 70% 12u ""
    Pop $TxtLdapHost

    ${NSD_CreateLabel} 72% 0u 28% 10u "Puerto:"
    Pop $0
    ${NSD_CreateText} 72% 10u 28% 12u "389"
    Pop $TxtLdapPort

    ; --- Base DN ---
    ${NSD_CreateLabel} 0 30u 100% 10u "Base DN (ej: DC=LAB-MH,DC=LOCAL):"
    Pop $0
    ${NSD_CreateText} 0 40u 100% 12u ""
    Pop $TxtAdBaseDn

    ; --- Search Base & Filter ---
    ${NSD_CreateLabel} 0 60u 48% 10u "LDAP Search Base:"
    Pop $0
    ${NSD_CreateText} 0 70u 48% 12u "cn=Users"
    Pop $TxtLdapSearchBase

    ${NSD_CreateLabel} 52% 60u 48% 10u "LDAP Search Filter:"
    Pop $0
    ${NSD_CreateText} 52% 70u 48% 12u "(sAMAccountName={0})"
    Pop $TxtLdapSearchFilter

    ; Restaurar estado
    ${If} $ValLdapHost != ""
        ${NSD_SetText} $TxtLdapHost $ValLdapHost
        ${NSD_SetText} $TxtLdapPort $ValLdapPort
        ${NSD_SetText} $TxtAdBaseDn $ValAdBaseDn
        ${NSD_SetText} $TxtLdapSearchBase $ValLdapSearchBase
        ${NSD_SetText} $TxtLdapSearchFilter $ValLdapSearchFilter
    ${EndIf}

    nsDialogs::Show
FunctionEnd

Function PageLDAPConnLeave
    ${NSD_GetText} $TxtLdapHost $ValLdapHost
    ${NSD_GetText} $TxtLdapPort $ValLdapPort
    ${NSD_GetText} $TxtAdBaseDn $ValAdBaseDn
    ${NSD_GetText} $TxtLdapSearchBase $ValLdapSearchBase
    ${NSD_GetText} $TxtLdapSearchFilter $ValLdapSearchFilter

    ${If} $ValLdapHost == ""
    ${OrIf} $ValLdapPort == ""
    ${OrIf} $ValAdBaseDn == ""
        MessageBox MB_ICONSTOP|MB_OK "Host, Puerto y Base DN son obligatorios."
        Abort
    ${EndIf}
FunctionEnd

; =====================================================================
; LÓGICA: PÁGINA 2 - CREDENCIALES Y SERVICIOS
; =====================================================================
Function PageLDAPCredsCreate
    !insertmacro MUI_HEADER_TEXT "Credenciales y Broker" "Ingrese las cuentas de servicio y el servidor de aplicaciones."
    nsDialogs::Create 1018
    Pop $Dialog
    ${If} $Dialog == error
        Abort
    ${EndIf}

    ; --- Credenciales LDAP ---
    ${NSD_CreateLabel} 0 0u 48% 10u "LDAP User DN:"
    Pop $0
    ${NSD_CreateText} 0 10u 48% 12u ""
    Pop $TxtLdapUser

    ${NSD_CreateLabel} 52% 0u 48% 10u "LDAP Password:"
    Pop $0
    ${NSD_CreatePassword} 52% 10u 48% 12u ""
    Pop $TxtLdapPass

    ; --- Credenciales de Servicio (Windows) ---
    ${NSD_CreateLabel} 0 30u 48% 10u "User Servicio (DOMINIO\Usuario):"
    Pop $0
    ${NSD_CreateText} 0 40u 48% 12u ""
    Pop $TxtSvcUser

    ${NSD_CreateLabel} 52% 30u 48% 10u "Contraseña de Servicio:"
    Pop $0
    ${NSD_CreatePassword} 52% 40u 48% 12u ""
    Pop $TxtSvcPass

    ; --- Connection Broker ---
    ${NSD_CreateLabel} 0 60u 100% 10u "Servidor RD Connection Broker:"
    Pop $0
    ${NSD_CreateText} 0 70u 100% 12u ""
    Pop $TxtSrvRdcb

    ; Restaurar estado
    ${If} $ValLdapUser != ""
        ${NSD_SetText} $TxtLdapUser $ValLdapUser
        ${NSD_SetText} $TxtLdapPass $ValLdapPass
        ${NSD_SetText} $TxtSvcUser $ValSvcUser
        ${NSD_SetText} $TxtSvcPass $ValSvcPass
        ${NSD_SetText} $TxtSrvRdcb $ValSrvRdcb
    ${EndIf}

    nsDialogs::Show
FunctionEnd

Function PageLDAPCredsLeave
    ${NSD_GetText} $TxtLdapUser $ValLdapUser
    ${NSD_GetText} $TxtLdapPass $ValLdapPass
    ${NSD_GetText} $TxtSvcUser $ValSvcUser
    ${NSD_GetText} $TxtSvcPass $ValSvcPass
    ${NSD_GetText} $TxtSrvRdcb $ValSrvRdcb

    ${If} $ValLdapUser == ""
    ${OrIf} $ValLdapPass == ""
    ${OrIf} $ValSvcUser == ""
    ${OrIf} $ValSvcPass == ""
        MessageBox MB_ICONSTOP|MB_OK "Las credenciales LDAP y de Servicio son obligatorias."
        Abort
    ${EndIf}

    ${If} $ValSrvRdcb == ""
        MessageBox MB_ICONSTOP|MB_OK "Debe ingresar el servidor RD Connection Broker."
        Abort
    ${EndIf}

    ; --- Validar formato estricto DOMINIO\Usuario ---
    ${WordFind} "$ValSvcUser" "\" "#" $0
    ${If} $0 != 2
        MessageBox MB_ICONSTOP|MB_OK "El Usuario de Servicio debe tener estrictamente el formato DOMINIO\Usuario."
        Abort
    ${EndIf}

    ; =================================================================
    ; VALIDAR CREDENCIALES CONTRA AD (Solo cuenta de servicio)
    ; =================================================================
    InitPluginsDir
    FileOpen $0 "$PLUGINSDIR\ad-pass.dat" w
    FileWrite $0 $ValSvcPass
    FileClose $0

    FileOpen $0 "$PLUGINSDIR\test-ad.ps1" w
    FileWrite $0 "param([string]$$svcUser)$\r$\n"
    FileWrite $0 "$$pass = (Get-Content '$PLUGINSDIR\ad-pass.dat' -Raw).Trim()$\r$\n"
    FileWrite $0 "$$domain = ($$svcUser -split '\\')[0]$\r$\n"
    FileWrite $0 "$$user = ($$svcUser -split '\\')[1]$\r$\n"
    FileWrite $0 "try {$\r$\n"
    FileWrite $0 "    Add-Type -AssemblyName System.DirectoryServices.AccountManagement$\r$\n"
    FileWrite $0 "    $$context = [System.DirectoryServices.AccountManagement.PrincipalContext]::new([System.DirectoryServices.AccountManagement.ContextType]::Domain, $$domain)$\r$\n"
    FileWrite $0 "    if ($$context.ValidateCredentials($$user, $$pass)) { exit 0 } else { exit 1 }$\r$\n"
    FileWrite $0 "} catch {$\r$\n"
    FileWrite $0 "    exit 2$\r$\n"
    FileWrite $0 "}$\r$\n"
    FileClose $0

    System::Call 'user32::LoadCursor(i 0, i 32514) i .r0'
    System::Call 'user32::SetCursor(i r0)'

    nsExec::Exec '"$WINDIR\Sysnative\WindowsPowerShell\v1.0\powershell.exe" -ExecutionPolicy Bypass -WindowStyle Hidden -NoProfile -File "$PLUGINSDIR\test-ad.ps1" "$ValSvcUser"'
    Pop $0
    Delete "$PLUGINSDIR\ad-pass.dat"
    
    ${If} $0 == 1
        MessageBox MB_ICONSTOP|MB_OK "La contraseña ingresada no es válida para la cuenta de servicio.\r\nPor favor, verifique e intente de nuevo."
        Abort
    ${ElseIf} $0 == 2
        MessageBox MB_ICONEXCLAMATION|MB_OK "No se pudo contactar al Dominio para validar la contraseña.\r\nVerifique que el formato DOMINIO\Usuario sea correcto."
        Abort
    ${EndIf}

    ; =================================================================
    ; PRE-CARGAR CERTIFICADOS (para la siguiente página)
    ; =================================================================
    FileOpen $0 "$PLUGINSDIR\enum-certs.ps1" w
    FileWrite $0 "$$certs = Get-ChildItem Cert:\LocalMachine\My | Where-Object { $$_.HasPrivateKey -and $$_.NotAfter -gt (Get-Date) }$\r$\n"
    FileWrite $0 "$$certs_display = $$certs | ForEach-Object { $$_.Subject + ' (exp: ' + $$_.NotAfter.ToString('yyyy-MM-dd') + ')' }$\r$\n"
    FileWrite $0 "$$certs_thumb = $$certs | ForEach-Object { $$_.Thumbprint }$\r$\n"
    FileWrite $0 "[System.IO.File]::WriteAllLines('$PLUGINSDIR\certs_list.txt', $$certs_display, (New-Object System.Text.UTF8Encoding($$false)))$\r$\n"
    FileWrite $0 "[System.IO.File]::WriteAllLines('$PLUGINSDIR\certs_thumb.txt', $$certs_thumb, (New-Object System.Text.UTF8Encoding($$false)))$\r$\n"
    FileClose $0

    nsExec::Exec '"$WINDIR\Sysnative\WindowsPowerShell\v1.0\powershell.exe" -ExecutionPolicy Bypass -WindowStyle Hidden -NoProfile -File "$PLUGINSDIR\enum-certs.ps1"'
FunctionEnd

; =====================================================================
; LÓGICA: PÁGINA DE CERTIFICADO SSL
; =====================================================================
Function PageCertCreate
    !insertmacro MUI_HEADER_TEXT "Certificado SSL" "Seleccione el certificado SSL que se usará para el sitio HTTPS del portal."
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

    StrCpy $2 ""
    ${If} $ValHost != ""
        StrCpy $2 $ValHost
    ${EndIf}
    
    ${NSD_CreateText} 0 65u 100% 12u "$2"
    Pop $TxtHost

    ClearErrors
    FileOpen $0 "$PLUGINSDIR\certs_list.txt" r
    ${If} $0 != ""
        ${Do}
            FileRead $0 $1
            IfErrors 0 +2
                ${ExitDo}
            
            StrLen $2 $1
            IntOp $2 $2 - 2
            StrCpy $1 $1 $2
            
            ${If} $1 != ""
                ${NSD_CB_AddString} $CmbCert $1
            ${EndIf}
        ${Loop}
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

    SendMessage $CmbCert ${CB_GETCURSEL} 0 0
    Pop $0
    ${If} $0 == -1
        MessageBox MB_ICONSTOP|MB_OK "Debe seleccionar un certificado SSL válido para continuar."
        Abort
    ${EndIf}

    FileOpen $1 "$PLUGINSDIR\certs_thumb.txt" r
    ${If} $1 == ""
        MessageBox MB_ICONSTOP|MB_OK "No se pudo cargar la información de certificados (thumbprints)."
        Abort
    ${EndIf}
    
    StrCpy $2 0
    ${Do}
        FileRead $1 $3
        IfErrors 0 +2
            ${ExitDo}
        
        StrLen $4 $3
        IntOp $4 $4 - 2
        StrCpy $3 $3 $4
        
        ${If} $2 == $0
            StrCpy $ValCertThumbprint $3
            ${ExitDo}
        ${EndIf}
        IntOp $2 $2 + 1
    ${Loop}
    FileClose $1
FunctionEnd

; =====================================================================
; COMPONENTES / SECCIONES PRINCIPALES
; =====================================================================

Section "Prerrequisitos IIS (URL Rewrite 2.1 y ARR 3.0)" SEC_PREREQS
    SetOutPath "$TEMP"
    File "scripts\setup-iis-prereqs.ps1"
    File "scripts\setup-backend-service.ps1"
    File "scripts\setup-iis-site.ps1"

    SetOutPath "$TEMP\prereqs"
    File /r "prereqs\*"

    CreateDirectory "$INSTDIR\backend\logs"
    !insertmacro ExecPowerShell "$TEMP\setup-iis-prereqs.ps1" '-PrereqsDir "$TEMP\prereqs" -LogFile "$INSTDIR\backend\logs\install-prereqs.log"'
SectionEnd


Section "Backend ${BackendType} (API + Servicio Windows)" SEC_BACKEND
    DetailPrint "Deteniendo servicio/procesos existentes (si aplica)..."
    nsExec::Exec 'powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "if (Get-Service -Name \"${ServiceName}\" -ErrorAction SilentlyContinue) { Stop-Service -Name \"${ServiceName}\" -Force -ErrorAction SilentlyContinue; Start-Sleep -Seconds 3 }"'
    nsExec::Exec 'taskkill /F /IM main.exe 2>NUL'
    nsExec::Exec 'taskkill /F /IM node.exe 2>NUL'

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

    ; --- Extracción de Dominio y Usuario para NSSM ---
    ${WordFind} "$ValSvcUser" "\" "-1" $R1 ; Obtiene el Usuario
    ${WordFind} "$ValSvcUser" "\" "+1" $R2 ; Obtiene el Dominio

    ; --- Escritura de Configuración (.env) ---
    DetailPrint "Generando archivo de configuración .env..."
    
    FileOpen $0 "$INSTDIR\backend\.env.tmp" w
    FileWrite $0 "# ============================================================$\r$\n"
    FileWrite $0 "# RDWeb Portal - Generado por el Instalador$\r$\n"
    FileWrite $0 "# ============================================================$\r$\n$\r$\n"
    
    FileWrite $0 "PORT=3000$\r$\nNODE_ENV=production$\r$\nJWT_SECRET=$\"$1$\"$\r$\nJWT_EXPIRES_IN=1h$\r$\n$\r$\n"
    FileWrite $0 "LDAP_HOST=$\"$ValLdapHost$\"$\r$\nLDAP_PORT=$\"$ValLdapPort$\"$\r$\nLDAP_BASE_DN=$\"$ValAdBaseDn$\"$\r$\n"
    FileWrite $0 "LDAP_USER_DN=$\"$ValLdapUser$\"$\r$\nLDAP_PASSWORD=$\"$ValLdapPass$\"$\r$\n"
    FileWrite $0 "LDAP_USER_SEARCH_BASE=$\"$ValLdapSearchBase$\"$\r$\nLDAP_USER_SEARCH_FILTER=$\"$ValLdapSearchFilter$\"$\r$\n$\r$\n"
    FileWrite $0 "RDCB_SERVER=$\"$ValSrvRdcb$\"$\r$\n"
    FileWrite $0 "CERT_THUMBPRINT=$\"$ValCertThumbprint$\"$\r$\n$\r$\n"
    FileWrite $0 "RDP_GATEWAY_CREDENTIAL_SOURCE=0$\r$\nRDP_PROMPT_CREDENTIAL_ONCE=true$\r$\n"
    FileWrite $0 "RDP_PROMPT_FOR_CREDENTIALS_ON_CLIENT=true$\r$\nRDP_USE_MULTIMON=true$\r$\n"
    FileWrite $0 "RDP_SPAN_MONITORS=true$\r$\nSIMULATION_MODE=false$\r$\n"
    FileClose $0

    FileOpen $0 "$PLUGINSDIR\convert-env.ps1" w
    FileWrite $0 "$$content = Get-Content -Path '$INSTDIR\backend\.env.tmp' -Raw$\r$\n"
    FileWrite $0 "[System.IO.File]::WriteAllText('$INSTDIR\backend\.env', $$content, (New-Object System.Text.UTF8Encoding($$false)))$\r$\n"
    FileWrite $0 "Remove-Item '$INSTDIR\backend\.env.tmp' -Force$\r$\n"
    FileClose $0

    nsExec::Exec '"$WINDIR\Sysnative\WindowsPowerShell\v1.0\powershell.exe" -ExecutionPolicy Bypass -WindowStyle Hidden -NoProfile -File "$PLUGINSDIR\convert-env.ps1"'

    ; --- Configurar Servicio NSSM ---
    DetailPrint "Configurando servicio backend..."
    CreateDirectory "$INSTDIR\backend\logs"
    
    FileOpen $0 "$TEMP\svcpwd.dat" w
    FileWrite $0 $ValSvcPass
    FileClose $0

    !insertmacro ExecPowerShell "$TEMP\setup-backend-service.ps1" '-BackendDir "$INSTDIR\backend" -ServiceName "${ServiceName}" -BackendType "${BackendType}" -ServiceUser "$R1" -ServiceDomain "$R2" -CredentialFile "$TEMP\svcpwd.dat" -LogFile "$INSTDIR\backend\logs\install-service.log"'
    Delete "$TEMP\svcpwd.dat"
SectionEnd

Section "Frontend Angular (archivos estáticos IIS)" SEC_FRONTEND
    SetOutPath "$INSTDIR\frontend"
    File /r "frontend\*"

    DetailPrint "Configurando sitio IIS..."
    !insertmacro ExecPowerShell "$TEMP\setup-iis-site.ps1" '-SiteName "${MyAppName}" -FrontendDir "$INSTDIR\frontend" -CertThumbprint "$ValCertThumbprint" -HostName "$ValHost" -LogFile "$INSTDIR\backend\logs\install-iis-site.log"'

    SetOutPath "$INSTDIR\assets\installer"
    File "assets\installer\app-icon.ico"
    SetOutPath "$INSTDIR\scripts"
    File "scripts\uninstall-backend-service.ps1"
    File "scripts\uninstall-iis-site.ps1"

    WriteUninstaller "$INSTDIR\uninstall.exe"
    
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
    !insertmacro ExecPowerShellQuiet "$INSTDIR\scripts\uninstall-iis-site.ps1" '-SiteName "${MyAppName}"'
    !insertmacro ExecPowerShellQuiet "$INSTDIR\scripts\uninstall-backend-service.ps1" '-BackendDir "$INSTDIR\backend" -ServiceName "${ServiceName}"'

    DetailPrint "Eliminando archivos..."
    RMDir /r "$INSTDIR\backend"
    RMDir /r "$INSTDIR\frontend"
    RMDir /r "$INSTDIR\scripts"
    Delete "$INSTDIR\uninstall.exe"
    RMDir "$INSTDIR" 

    DetailPrint "Limpiando registro..."
    DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${MyAppName}"
SectionEnd