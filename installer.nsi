; =====================================================================
; Instalador NSIS - Portal RD Web (Refactorizado)
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

!ifndef MyAppVersion
  !define MyAppVersion "1.0.0"
!endif

!ifndef BackendType
  !define BackendType "express"
!endif

; =====================================================================
; MACROS REUTILIZABLES
; =====================================================================
; Ejecución centralizada y segura de PowerShell con manejo de errores
!macro ExecPowerShell ScriptPath Arguments
    Push $R0 ; Protegemos el valor original de $R0
    DetailPrint "Ejecutando: ${ScriptPath}..."
    nsExec::ExecToLog '"$WINDIR\Sysnative\WindowsPowerShell\v1.0\powershell.exe" -ExecutionPolicy Bypass -NoProfile -File "${ScriptPath}" ${Arguments}'
    Pop $R0  ; Obtenemos el Exit Code de PowerShell
    ${If} $R0 != 0
        MessageBox MB_ICONSTOP|MB_OK "Fallo crítico al ejecutar: ${ScriptPath}$\r$\nCódigo de error: $R0.$\r$\nRevise los logs en la carpeta destino para más detalles."
        Abort "Instalación abortada por fallo en script externo."
    ${EndIf}
    Pop $R0  ; Restauramos el valor original de $R0
!macroend

; Ejecución silenciosa para procesos de desinstalación (no detiene el proceso si falla)
!macro ExecPowerShellQuiet ScriptPath Arguments
    Push $R0
    DetailPrint "Desinstalando (Ejecutando script): ${ScriptPath}..."
    nsExec::ExecToLog '"$WINDIR\Sysnative\WindowsPowerShell\v1.0\powershell.exe" -ExecutionPolicy Bypass -NoProfile -File "${ScriptPath}" ${Arguments}'
    Pop $R0  ; Descartamos el Exit Code
    Pop $R0  ; Restauramos la pila
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
; CONFIGURACIÓN DEL INSTALADOR Y UI
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
!define MUI_COMPONENTSPAGE_NODESC

; -- Orden de Páginas --
!insertmacro MUI_PAGE_WELCOME
!define MUI_PAGE_CUSTOMFUNCTION_SHOW PageADShow
Page custom PageADCreate PageADLeave
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
; LÓGICA: PÁGINA DE ACTIVE DIRECTORY
; =====================================================================
Function PageADCreate
    !insertmacro MUI_HEADER_TEXT "Configuración de Active Directory y Servidores" "Configure la conexión LDAP al controlador de dominio y los servidores del portal."
    nsDialogs::Create 1018
    Pop $Dialog
    ${If} $Dialog == error
        Abort
    ${EndIf}

    ; --- LDAP URL ---
    ${NSD_CreateLabel} 0 0u 100% 10u "URL LDAP del Domain Controller:"
    Pop $0
    ${NSD_CreateText} 0 10u 100% 12u ""
    Pop $TxtAdLdap

    ${NSD_CreateLabel} 0 25u 100% 10u "Base DN del dominio:"
    Pop $0
    ${NSD_CreateText} 0 35u 100% 12u ""
    Pop $TxtAdBaseDn

    ; --- Dominio y Credenciales ---
    ${NSD_CreateLabel} 0 50u 100% 10u "Dominio NetBIOS:"
    Pop $0
    ${NSD_CreateText} 0 60u 100% 12u ""
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

; =====================================================================
; CALLBACK: Mostrar / inicializar valores rápidos al mostrar la página AD
; =====================================================================
Function PageADShow
    ; Rellenar valores por defecto (rápidos) al mostrar la página
    ReadEnvStr $2 "LOGONSERVER"
    ReadEnvStr $3 "USERDNSDOMAIN"
    ${WordFind} "$2" "\" "-1" $2

    ; Calcular Base DN (si existe USERDNSDOMAIN)
    ${If} $3 == ""
        StrCpy $1 ""
    ${Else}
        Push $R0
        Push $R1
        Push $R2
        Push $R3
        Push $R4
        Push $R5

        StrCpy $R0 $3
        StrCpy $R1 ""
        StrCpy $R2 ""
        StrLen $R3 $R0
        
        ${For} $R4 0 $R3
            StrCpy $R5 $R0 1 $R4
            ${If} $R5 == "."
            ${OrIf} $R4 == $R3
                ${If} $R1 != ""
                    ${If} $R2 == ""
                        StrCpy $R2 "DC=$R1"
                    ${Else}
                        StrCpy $R2 "$R2,DC=$R1"
                    ${EndIf}
                    StrCpy $R1 ""
                ${EndIf}
            ${Else}
                StrCpy $R1 "$R1$R5"
            ${EndIf}
        ${Next}
        StrCpy $1 $R2

        Pop $R5
        Pop $R4
        Pop $R3
        Pop $R2
        Pop $R1
        Pop $R0
    ${EndIf}

    ${NSD_SetText} $TxtAdLdap "ldap://$2.$3"
    ${NSD_SetText} $TxtAdBaseDn "$1"
    ReadEnvStr $4 "USERDOMAIN"
    ${NSD_SetText} $TxtAdDomain "$4"
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

    ReadEnvStr $0 "COMPUTERNAME"
    ReadEnvStr $1 "USERDNSDOMAIN"
    ${If} $1 != ""
        StrCpy $2 "$0.$1"
    ${Else}
        StrCpy $2 "$0"
    ${EndIf}
    ${NSD_CreateText} 0 65u 100% 12u "$2"
    Pop $TxtHost

    ; Extraer y listar certificados vía PowerShell
    InitPluginsDir
    FileOpen $0 "$PLUGINSDIR\enum-certs.ps1" w
    FileWrite $0 "$$certs = Get-ChildItem Cert:\LocalMachine\My | Where-Object { $$_.HasPrivateKey -and $$_.NotAfter -gt (Get-Date) }$\r$\n"
    FileWrite $0 "$$certs_display = $$certs | ForEach-Object { $$_.Subject + ' (exp: ' + $$_.NotAfter.ToString('yyyy-MM-dd') + ')' }$\r$\n"
    FileWrite $0 "$$certs_thumb = $$certs | ForEach-Object { $$_.Thumbprint }$\r$\n"
    FileWrite $0 "[System.IO.File]::WriteAllLines('$PLUGINSDIR\certs_list.txt', $$certs_display, (New-Object System.Text.UTF8Encoding($$false)))$\r$\n"
    FileWrite $0 "[System.IO.File]::WriteAllLines('$PLUGINSDIR\certs_thumb.txt', $$certs_thumb, (New-Object System.Text.UTF8Encoding($$false)))$\r$\n"
    FileClose $0

    nsExec::Exec 'powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -NoProfile -File "$PLUGINSDIR\enum-certs.ps1"'

    ; Cargar certificados en el ComboBox (Refactorizado con LogicLib)
    ClearErrors
    FileOpen $0 "$PLUGINSDIR\certs_list.txt" r
    ${If} $0 != ""
        ${Do}
            FileRead $0 $1
            IfErrors 0 +2
                ${ExitDo}
            
            ; Limpiar CRLF
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
    
    ; Leer el thumbprint correspondiente a la selección
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

    ; --- FIX-C6: Generar JWT Secreto con CSPRNG de PowerShell ---
    ; Reemplaza VBScript Rnd() (no criptográfico) por
    ; [System.Security.Cryptography.RandomNumberGenerator] (CSPRNG).
    ; Genera 32 bytes aleatorios → 64 caracteres hex (256 bits de entropía).
    DetailPrint "Generando archivo .env..."
    InitPluginsDir
    FileOpen $0 "$PLUGINSDIR\gen-jwt.ps1" w
    FileWrite $0 "$$bytes = New-Object byte[] 32$\r$\n"
    FileWrite $0 "[System.Security.Cryptography.RandomNumberGenerator]::Fill($$bytes)$\r$\n"
    FileWrite $0 "[System.Console]::Write(([BitConverter]::ToString($$bytes) -replace '-',''))$\r$\n"
    FileClose $0
    nsExec::ExecToStack '"$WINDIR\Sysnative\WindowsPowerShell\v1.0\powershell.exe" -ExecutionPolicy Bypass -NoProfile -File "$PLUGINSDIR\gen-jwt.ps1"'
    Pop $0
    Pop $1 ; JWT_SECRET en $1 (64 caracteres hex, 256 bits CSPRNG)

    ; --- Escritura de Configuración (.env) ---
    FileOpen $0 "$INSTDIR\backend\.env" w
    FileWrite $0 "# ============================================================$\r$\n"
    FileWrite $0 "# RDWeb Portal - Generado por el Instalador$\r$\n"
    FileWrite $0 "# ============================================================$\r$\n$\r$\n"
    FileWrite $0 "PORT=3000$\r$\nNODE_ENV=production$\r$\nJWT_SECRET=$1$\r$\nJWT_EXPIRES_IN=1h$\r$\n$\r$\n"
    FileWrite $0 "LDAP_URL=$ValAdLdap$\r$\nLDAP_BASE_DN=$ValAdBaseDn$\r$\nAD_DOMAIN=$ValAdDomain$\r$\n"
    FileWrite $0 "AD_SERVICE_USER=$ValAdUser$\r$\nAD_SERVICE_PASS=$ValAdPass$\r$\nRDCB_SERVER=$ValSrvRdcb$\r$\n$\r$\n"
    FileWrite $0 "RDP_GATEWAY_CREDENTIAL_SOURCE=0$\r$\nRDP_PROMPT_CREDENTIAL_ONCE=true$\r$\n"
    FileWrite $0 "RDP_PROMPT_FOR_CREDENTIALS_ON_CLIENT=true$\r$\nRDP_USE_MULTIMON=false$\r$\n"
    FileWrite $0 "RDP_SPAN_MONITORS=false$\r$\nSIMULATION_MODE=false$\r$\n"
    FileClose $0

    ; --- Configurar Servicio NSSM ---
    DetailPrint "Configurando servicio backend..."
    CreateDirectory "$INSTDIR\backend\logs"
    
    FileOpen $0 "$TEMP\svcpwd.dat" w
    FileWrite $0 $ValAdPass
    FileClose $0

    !insertmacro ExecPowerShell "$TEMP\setup-backend-service.ps1" '-BackendDir "$INSTDIR\backend" -ServiceName "${ServiceName}" -BackendType "${BackendType}" -ServiceUser "$ValAdUser" -ServiceDomain "$ValAdDomain" -CredentialFile "$TEMP\svcpwd.dat" -LogFile "$INSTDIR\backend\logs\install-service.log"'
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