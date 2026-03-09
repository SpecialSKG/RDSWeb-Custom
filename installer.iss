; =====================================================================
; Instalador Inno Setup — Portal RD Web (Backend + Frontend)
; =====================================================================
; Reemplaza el flujo ps2exe + install.ps1 con un instalador nativo
; de Windows profesional, con UI, desinstalador y componentes.
;
; Compilar:  ISCC.exe installer.iss
; Requiere:  Inno Setup 6.2+  (https://jrsoftware.org/isdownload.php)
; =====================================================================

#ifndef MyAppVersion
  #define MyAppVersion "1.0.0"
#endif

; Rutas fuente — build.ps1 las sobreescribe con /D para apuntar a Release\
; Valores por defecto: carpetas del repositorio (permite compilar desde el IDE)
#ifndef SrcBackend
  #define SrcBackend "backend"
#endif
#ifndef SrcFrontend
  #define SrcFrontend "frontend\dist\frontend\browser"
#endif
#ifndef SrcPrereqs
  #define SrcPrereqs "prereqs"
#endif
#ifndef SrcWebConfig
  #define SrcWebConfig "frontend\web.config"
#endif

; Timestamp de compilación (formato: yyyy-MM-dd_HH-mm)
#define MyTimestamp GetDateTimeString('yyyy-MM-dd_HH-mm', '-', '-')

#define MyAppName      "Portal RD Web"
#define MyAppPublisher "RDS Custom"
#define ServiceName    "RDSWeb"

; =====================================================================
; CONFIGURACIÓN GENERAL
; =====================================================================
[Setup]
AppId={{8F3A5E92-C147-4D6B-B21A-3E92F6D5C8A1}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName=C:\inetpub\wwwroot
DirExistsWarning=no
UsePreviousAppDir=yes
DisableProgramGroupPage=yes
OutputDir=releases
OutputBaseFilename=RDWeb-Portal-Installer-{#MyTimestamp}
Compression=lzma2/ultra64
SolidCompression=yes
PrivilegesRequired=admin
WizardStyle=modern
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
SetupLogging=yes
CloseApplications=no
UninstallDisplayName={#MyAppName}
UninstallDisplayIcon={app}\backend\node.exe
; Mínimo Windows Server 2016 / Windows 10
MinVersion=10.0

; =====================================================================
; IDIOMAS
; =====================================================================
[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

; =====================================================================
; MENSAJES PERSONALIZADOS
; =====================================================================
[CustomMessages]
; --- Español ---
spanish.ComponentPrereqs=Prerrequisitos IIS (URL Rewrite 2.1 y ARR 3.0)
spanish.ComponentBackend=Backend Node.js (API + Servicio Windows)
spanish.ComponentFrontend=Frontend Angular (archivos estáticos IIS)
spanish.CredTitle=Credenciales del Servicio
spanish.CredDescription=El servicio backend se ejecutará bajo la cuenta de dominio indicada abajo.%nIngrese la contraseña para configurar el servicio de Windows.
spanish.CredAccount=Cuenta de servicio:
spanish.CredPassword=Contraseña:
spanish.CredEmpty=Debe ingresar la contraseña de la cuenta de servicio.
spanish.StatusStopService=Deteniendo servicio anterior...
spanish.StatusPrereqs=Instalando prerrequisitos de IIS...
spanish.StatusService=Configurando servicio backend...
spanish.ErrPrereqs=Ocurrieron errores al instalar los prerrequisitos de IIS.%n%nRevise el log en:%n%1\install-prereqs.log
spanish.ErrService=Ocurrieron errores al configurar el servicio backend.%n%nRevise el log en:%n%1\install-service.log
spanish.DoneTitle=Recordatorios Post-Instalación
spanish.DoneReminder=La instalación ha finalizado correctamente.%n%nRecuerde:%n%n1. Verifique que el sitio IIS apunte a la carpeta del frontend.%n2. Revise el archivo .env en la carpeta backend si es la primera instalación.%n3. El Proxy Inverso de IIS fue habilitado automáticamente.
; --- English ---
english.ComponentPrereqs=IIS Prerequisites (URL Rewrite 2.1 & ARR 3.0)
english.ComponentBackend=Node.js Backend (API + Windows Service)
english.ComponentFrontend=Angular Frontend (IIS static files)
english.CredTitle=Service Credentials
english.CredDescription=The backend service will run under the domain account shown below.%nEnter the password to configure the Windows service.
english.CredAccount=Service account:
english.CredPassword=Password:
english.CredEmpty=You must enter the service account password.
english.StatusStopService=Stopping previous service...
english.StatusPrereqs=Installing IIS prerequisites...
english.StatusService=Configuring backend service...
english.ErrPrereqs=Errors occurred while installing IIS prerequisites.%n%nCheck the log at:%n%1\install-prereqs.log
english.ErrService=Errors occurred while configuring the backend service.%n%nCheck the log at:%n%1\install-service.log
english.DoneTitle=Post-Installation Reminders
english.DoneReminder=Installation completed successfully.%n%nRemember:%n%n1. Verify that the IIS site points to the frontend folder.%n2. Review the .env file in the backend folder if this is the first installation.%n3. The IIS Reverse Proxy was enabled automatically.

; =====================================================================
; TIPOS Y COMPONENTES
; =====================================================================
[Types]
Name: "full";   Description: "Instalación completa (recomendada)"
Name: "custom"; Description: "Personalizada"; Flags: iscustom

[Components]
Name: "prereqs";  Description: "{cm:ComponentPrereqs}";  Types: full
Name: "backend";  Description: "{cm:ComponentBackend}";  Types: full
Name: "frontend"; Description: "{cm:ComponentFrontend}"; Types: full

; =====================================================================
; ARCHIVOS
; =====================================================================
[Files]
; --- Backend: src, node_modules, package.json, nssm.exe, node.exe ---
Source: "{#SrcBackend}\src\*"; DestDir: "{app}\backend\src"; \
  Components: backend; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#SrcBackend}\node_modules\*"; DestDir: "{app}\backend\node_modules"; \
  Components: backend; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#SrcBackend}\package.json"; DestDir: "{app}\backend"; \
  Components: backend; Flags: ignoreversion
Source: "{#SrcBackend}\nssm.exe"; DestDir: "{app}\backend"; \
  Components: backend; Flags: ignoreversion
Source: "{#SrcBackend}\node.exe"; DestDir: "{app}\backend"; \
  Components: backend; Flags: ignoreversion

; .env: solo copiar en primera instalación (preserva config en upgrades)
Source: "{#SrcBackend}\.env"; DestDir: "{app}\backend"; \
  Components: backend; \
  Flags: onlyifdoesntexist uninsneveruninstall skipifsourcedoesntexist

; --- Frontend (archivos estáticos compilados de Angular) ---
Source: "{#SrcFrontend}\*"; DestDir: "{app}\frontend"; \
  Components: frontend; \
  Flags: ignoreversion recursesubdirs createallsubdirs

; web.config para IIS URL Rewrite en el frontend
Source: "{#SrcWebConfig}"; DestDir: "{app}\frontend"; \
  Components: frontend; Flags: ignoreversion skipifsourcedoesntexist

; --- Prerrequisitos (extraídos a carpeta temporal, se borran tras instalar) ---
Source: "{#SrcPrereqs}\*"; DestDir: "{tmp}\prereqs"; \
  Components: prereqs; Flags: ignoreversion deleteafterinstall

; --- Scripts de instalación (temporales — Inno Setup los invoca y los descarta) ---
Source: "scripts\setup-iis-prereqs.ps1";    DestDir: "{tmp}"; Flags: ignoreversion deleteafterinstall
Source: "scripts\setup-backend-service.ps1"; DestDir: "{tmp}"; Flags: ignoreversion deleteafterinstall

; --- Script de desinstalación (persiste junto a la aplicación) ---
Source: "scripts\uninstall-backend-service.ps1"; DestDir: "{app}\scripts"; Flags: ignoreversion

; =====================================================================
; DIRECTORIOS
; =====================================================================
[Dirs]
Name: "{app}\backend\logs"; Components: backend; Permissions: users-full

; =====================================================================
; DESINSTALACIÓN
; =====================================================================
[UninstallRun]
Filename: "powershell.exe"; \
  Parameters: "-ExecutionPolicy Bypass -NoProfile -File ""{app}\scripts\uninstall-backend-service.ps1"" -BackendDir ""{app}\backend"" -ServiceName ""{#ServiceName}"""; \
  Flags: runhidden waituntilterminated

[UninstallDelete]
Type: filesandordirs; Name: "{app}\backend\logs"
Type: filesandordirs; Name: "{app}\scripts"

; =====================================================================
; PASCAL SCRIPT — Lógica personalizada del instalador
; =====================================================================
[Code]
var
  CredPage: TInputQueryWizardPage;

(* ----------------------------------------------------------------- *)
(* Página personalizada: Credenciales del servicio                    *)
(* ----------------------------------------------------------------- *)
procedure InitializeWizard;
var
  AccountStr: String;
begin
  AccountStr := GetEnv('USERDOMAIN') + '\' + GetEnv('USERNAME');

  CredPage := CreateInputQueryPage(
    wpSelectComponents,
    ExpandConstant('{cm:CredTitle}'),
    ExpandConstant('{cm:CredDescription}'),
    ExpandConstant('{cm:CredAccount}') + ' ' + AccountStr
  );
  CredPage.Add(ExpandConstant('{cm:CredPassword}'), True); { True = campo password }
end;

(* Ocultar página de credenciales si no se instala el backend *)
function ShouldSkipPage(PageID: Integer): Boolean;
begin
  Result := False;
  if PageID = CredPage.ID then
    Result := not WizardIsComponentSelected('backend');
end;

(* Validar que se ingresó una contraseña *)
function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;
  if CurPageID = CredPage.ID then
  begin
    if Trim(CredPage.Values[0]) = '' then
    begin
      MsgBox(ExpandConstant('{cm:CredEmpty}'), mbError, MB_OK);
      Result := False;
    end;
  end;
end;

(* ----------------------------------------------------------------- *)
(* Archivo temporal de contraseña (evita pasar por línea de comando)  *)
(* ----------------------------------------------------------------- *)
procedure SavePasswordToFile;
begin
  SaveStringToFile(ExpandConstant('{tmp}\svcpwd.dat'), CredPage.Values[0], False);
end;

(* ----------------------------------------------------------------- *)
(* PrepareToInstall: detener servicio existente antes de copiar       *)
(* archivos, para evitar bloqueos en node.exe / nssm.exe             *)
(* ----------------------------------------------------------------- *)
function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  RC: Integer;
begin
  Result := '';
  NeedsRestart := False;
  WizardForm.PreparingLabel.Caption := ExpandConstant('{cm:StatusStopService}');
  Exec('powershell.exe',
    '-ExecutionPolicy Bypass -NoProfile -Command "' +
    'if (Get-Service -Name ''{#ServiceName}'' -ErrorAction SilentlyContinue) { ' +
    'Stop-Service -Name ''{#ServiceName}'' -Force -ErrorAction SilentlyContinue; ' +
    'Start-Sleep -Seconds 3 }"',
    '', SW_HIDE, ewWaitUntilTerminated, RC);
end;

(* ----------------------------------------------------------------- *)
(* Post-instalación: ejecutar scripts de configuración con control    *)
(* de errores (exit code) y mensajes al usuario                      *)
(* ----------------------------------------------------------------- *)
procedure CurStepChanged(CurStep: TSetupStep);
var
  RC: Integer;
  LogDir: String;
begin
  { Guardar contraseña a archivo temporal antes de la copia de archivos }
  if CurStep = ssInstall then
  begin
    if WizardIsComponentSelected('backend') then
      SavePasswordToFile;
  end;

  { Tras la copia de archivos: configurar IIS y servicio }
  if CurStep = ssPostInstall then
  begin
    LogDir := ExpandConstant('{app}\backend\logs');
    ForceDirectories(LogDir);

    { ── Fase 1: Prerrequisitos IIS ── }
    if WizardIsComponentSelected('prereqs') then
    begin
      WizardForm.StatusLabel.Caption := ExpandConstant('{cm:StatusPrereqs}');
      if not Exec('powershell.exe',
        ExpandConstant('-ExecutionPolicy Bypass -NoProfile -File "{tmp}\setup-iis-prereqs.ps1"' +
          ' -PrereqsDir "{tmp}\prereqs"' +
          ' -LogFile "{app}\backend\logs\install-prereqs.log"'),
        '', SW_HIDE, ewWaitUntilTerminated, RC) or (RC <> 0) then
      begin
        MsgBox(FmtMessage(ExpandConstant('{cm:ErrPrereqs}'), [LogDir]), mbError, MB_OK);
      end;
    end;

    { ── Fase 2: Servicio Backend ── }
    if WizardIsComponentSelected('backend') then
    begin
      WizardForm.StatusLabel.Caption := ExpandConstant('{cm:StatusService}');
      if not Exec('powershell.exe',
        ExpandConstant('-ExecutionPolicy Bypass -NoProfile -File "{tmp}\setup-backend-service.ps1"' +
          ' -BackendDir "{app}\backend"' +
          ' -ServiceName "{#ServiceName}"' +
          ' -PasswordFile "{tmp}\svcpwd.dat"' +
          ' -LogFile "{app}\backend\logs\install-service.log"'),
        '', SW_HIDE, ewWaitUntilTerminated, RC) or (RC <> 0) then
      begin
        MsgBox(FmtMessage(ExpandConstant('{cm:ErrService}'), [LogDir]), mbError, MB_OK);
      end;
    end;

    { Mostrar recordatorios finales }
    MsgBox(ExpandConstant('{cm:DoneReminder}'), mbInformation, MB_OK);
  end;
end;

(* ----------------------------------------------------------------- *)
(* Limpieza: eliminar archivo temporal de contraseña al cerrar        *)
(* ----------------------------------------------------------------- *)
procedure DeinitializeSetup;
var
  PwdFile: String;
begin
  PwdFile := ExpandConstant('{tmp}\svcpwd.dat');
  if FileExists(PwdFile) then
    DeleteFile(PwdFile);
end;
