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

; Tipo de backend: "express" (Node.js) o "python" (FastAPI)
; build.ps1 lo sobreescribe con /DBackendType=...
#ifndef BackendType
  #define BackendType "express"
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
#if BackendType == "python"
UninstallDisplayIcon={app}\backend\main.exe
#else
UninstallDisplayIcon={app}\backend\node.exe
#endif
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
#if BackendType == "python"
spanish.ComponentBackend=Backend Python (API + Servicio Windows)
#else
spanish.ComponentBackend=Backend Node.js (API + Servicio Windows)
#endif
spanish.ComponentFrontend=Frontend Angular (archivos estáticos IIS)
spanish.CredTitle=Credenciales del Servicio
spanish.CredDescription=El servicio backend se ejecutará bajo la cuenta de dominio indicada abajo.%nIngrese la contraseña para configurar el servicio de Windows.
spanish.CredAccount=Cuenta de servicio:
spanish.CredPassword=Contraseña:
spanish.CredEmpty=Debe ingresar la contraseña de la cuenta de servicio.
spanish.CredValidating=Validando credenciales contra Active Directory...
spanish.CredInvalid=La contraseña ingresada no es válida para la cuenta de servicio.%n%nPor favor, verifique e intente de nuevo.
spanish.CredDomainWarn=No se pudo validar la contraseña contra el dominio.%nLa instalación continuará, pero si la contraseña es incorrecta el servicio no podrá iniciar.
spanish.StatusStopService=Deteniendo servicio anterior...
spanish.StatusPrereqs=Instalando prerrequisitos de IIS...
spanish.StatusService=Configurando servicio backend...
spanish.ErrPrereqs=Ocurrieron errores al instalar los prerrequisitos de IIS.%n%nRevise el log en:%n%1\install-prereqs.log
spanish.ErrService=Ocurrieron errores al configurar el servicio backend.%n%nRevise el log en:%n%1\install-service.log
spanish.DoneTitle=Recordatorios Post-Instalación
spanish.DoneReminder=La instalación ha finalizado correctamente.%n%nRecuerde:%n%n1. Verifique que el sitio IIS apunte a la carpeta del frontend.%n2. El archivo .env fue generado con los valores del asistente.%n3. El Proxy Inverso de IIS fue habilitado automáticamente.
spanish.ADTitle=Configuración de Active Directory
spanish.ADDescription=Configure la conexión LDAP al controlador de dominio y la cuenta de servicio que el backend usará para consultar el directorio.
spanish.ADLdapUrl=URL LDAP del Domain Controller:
spanish.ADBaseDN=Base DN del dominio:
spanish.ADDomain=Dominio NetBIOS:
spanish.ADServiceUser=Cuenta de servicio AD (formato UPN):
spanish.ADServicePass=Contraseña de la cuenta de servicio AD:
spanish.ADFieldsRequired=Todos los campos de Active Directory son obligatorios.
spanish.SrvTitle=Servidores y Servicios
spanish.SrvDescription=Configure las direcciones de los servidores que utiliza el portal.
spanish.SrvRDCB=Servidor RD Connection Broker:
spanish.SrvFieldsRequired=Debe completar todos los campos de servidores.
spanish.CertTitle=Certificado SSL
spanish.CertDescription=Seleccione el certificado SSL que se usara para el sitio HTTPS del portal.%nSolo se muestran certificados validos del almacen LocalMachine\My con clave privada.
spanish.CertLabel=Certificado:
spanish.CertEmpty=Debe seleccionar un certificado SSL.
spanish.CertNone=No se encontraron certificados SSL validos en este equipo.%nInstale un certificado en LocalMachine\My antes de continuar.
spanish.StatusIISSite=Configurando sitio IIS...
spanish.ErrIISSite=Ocurrieron errores al configurar el sitio IIS.%n%nRevise el log en:%n%1\install-iis-site.log
; --- English ---
english.ComponentPrereqs=IIS Prerequisites (URL Rewrite 2.1 & ARR 3.0)
#if BackendType == "python"
english.ComponentBackend=Python Backend (API + Windows Service)
#else
english.ComponentBackend=Node.js Backend (API + Windows Service)
#endif
english.ComponentFrontend=Angular Frontend (IIS static files)
english.CredTitle=Service Credentials
english.CredDescription=The backend service will run under the domain account shown below.%nEnter the password to configure the Windows service.
english.CredAccount=Service account:
english.CredPassword=Password:
english.CredEmpty=You must enter the service account password.
english.CredValidating=Validating credentials against Active Directory...
english.CredInvalid=The password entered is not valid for the service account.%n%nPlease verify and try again.
english.CredDomainWarn=Could not validate the password against the domain.%nInstallation will continue, but the service may fail to start if the password is incorrect.
english.StatusStopService=Stopping previous service...
english.StatusPrereqs=Installing IIS prerequisites...
english.StatusService=Configuring backend service...
english.ErrPrereqs=Errors occurred while installing IIS prerequisites.%n%nCheck the log at:%n%1\install-prereqs.log
english.ErrService=Errors occurred while configuring the backend service.%n%nCheck the log at:%n%1\install-service.log
english.DoneTitle=Post-Installation Reminders
english.DoneReminder=Installation completed successfully.%n%nRemember:%n%n1. Verify that the IIS site points to the frontend folder.%n2. The .env file was generated with the values entered in the wizard.%n3. The IIS Reverse Proxy was enabled automatically.
english.ADTitle=Active Directory Configuration
english.ADDescription=Configure the LDAP connection to the domain controller and the service account the backend will use to query the directory.
english.ADLdapUrl=Domain Controller LDAP URL:
english.ADBaseDN=Domain Base DN:
english.ADDomain=NetBIOS Domain:
english.ADServiceUser=AD service account (UPN format):
english.ADServicePass=AD service account password:
english.ADFieldsRequired=All Active Directory fields are required.
english.SrvTitle=Servers and Services
english.SrvDescription=Configure the server addresses used by the portal.
english.SrvRDCB=RD Connection Broker server:
english.SrvFieldsRequired=All server fields are required.
english.CertTitle=SSL Certificate
english.CertDescription=Select the SSL certificate to use for the portal HTTPS site.%nOnly valid certificates from the LocalMachine\My store with a private key are shown.
english.CertLabel=Certificate:
english.CertEmpty=You must select an SSL certificate.
english.CertNone=No valid SSL certificates were found on this machine.%nPlease install a certificate in LocalMachine\My before continuing.
english.StatusIISSite=Configuring IIS site...
english.ErrIISSite=Errors occurred while configuring the IIS site.%n%nCheck the log at:%n%1\install-iis-site.log

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
#if BackendType == "python"
; --- Backend Python: main.exe (PyInstaller) + nssm.exe ---
Source: "{#SrcBackend}\main.exe"; DestDir: "{app}\backend"; \
  Components: backend; Flags: ignoreversion
Source: "{#SrcBackend}\nssm.exe"; DestDir: "{app}\backend"; \
  Components: backend; Flags: ignoreversion
#else
; --- Backend Express: src, node_modules, package.json, nssm.exe, node.exe ---
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
#endif

; .env se genera desde el asistente (ver WriteEnvFile en [Code])

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
Source: "scripts\setup-iis-site.ps1";        DestDir: "{tmp}"; Flags: ignoreversion deleteafterinstall

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
  ADPage: TInputQueryWizardPage;
  ServersPage: TInputQueryWizardPage;
  CertPage: TWizardPage;
  CertCombo: TNewComboBox;
  CertThumbprints: TArrayOfString;
  CertCount: Integer;
  CertsEnumerated: Boolean;
  EnvLoaded: Boolean;

(* ================================================================= *)
(* UTILIDADES                                                         *)
(* ================================================================= *)

{ Leer KEY=VALUE de un contenido .env cargado en memoria }
function GetEnvFileValue(const EnvContent: AnsiString; const Key: String): String;
var
  SearchStr: AnsiString;
  Content: AnsiString;
  P, E: Integer;
begin
  Result := '';
  Content := #10 + EnvContent;
  SearchStr := #10 + Key + '=';
  P := Pos(SearchStr, Content);
  if P > 0 then
  begin
    P := P + Length(SearchStr);
    E := P;
    while (E <= Length(Content)) and (Content[E] <> #13) and (Content[E] <> #10) do
      Inc(E);
    Result := Copy(Content, P, E - P);
  end;
end;

{ Generar cadena hexadecimal aleatoria (para JWT_SECRET) }
function GenerateRandomHex(Len: Integer): String;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Len do
    Result := Result + Copy('0123456789abcdef', Random(16) + 1, 1);
end;

{ Auto-detectar Base DN desde USERDNSDOMAIN (LAB-MH.LOCAL -> DC=LAB-MH,DC=LOCAL) }
function AutoDetectBaseDN: String;
var
  DNS, Part: String;
  P: Integer;
begin
  Result := '';
  DNS := Uppercase(GetEnv('USERDNSDOMAIN'));
  if DNS = '' then Exit;
  while DNS <> '' do
  begin
    P := Pos('.', DNS);
    if P > 0 then
    begin
      Part := Copy(DNS, 1, P - 1);
      DNS := Copy(DNS, P + 1, Length(DNS));
    end
    else begin
      Part := DNS;
      DNS := '';
    end;
    if Result <> '' then Result := Result + ',';
    Result := Result + 'DC=' + Part;
  end;
end;

{ Auto-detectar URL LDAP desde LOGONSERVER + USERDNSDOMAIN }
function AutoDetectLdapUrl: String;
var
  Srv, Dom: String;
begin
  Srv := GetEnv('LOGONSERVER');
  Dom := GetEnv('USERDNSDOMAIN');
  while (Length(Srv) > 0) and (Srv[1] = '\') do
    Srv := Copy(Srv, 2, Length(Srv));
  if (Srv <> '') and (Dom <> '') then
    Result := 'ldap://' + Srv + '.' + Dom
  else if Srv <> '' then
    Result := 'ldap://' + Srv
  else
    Result := 'ldap://';
end;

{ Cargar valores de un .env existente en las paginas del wizard (upgrade) }
procedure LoadExistingEnvValues;
var
  EnvPath, Val: String;
  Content: AnsiString;
begin
  EnvPath := ExpandConstant('{app}\backend\.env');
  if not FileExists(EnvPath) then Exit;
  if not LoadStringFromFile(EnvPath, Content) then Exit;

  Val := GetEnvFileValue(Content, 'LDAP_URL');
  if Val <> '' then ADPage.Values[0] := Val;
  Val := GetEnvFileValue(Content, 'LDAP_BASE_DN');
  if Val <> '' then ADPage.Values[1] := Val;
  Val := GetEnvFileValue(Content, 'AD_DOMAIN');
  if Val <> '' then ADPage.Values[2] := Val;
  Val := GetEnvFileValue(Content, 'AD_SERVICE_USER');
  if Val <> '' then ADPage.Values[3] := Val;
  Val := GetEnvFileValue(Content, 'AD_SERVICE_PASS');
  if Val <> '' then ADPage.Values[4] := Val;
  Val := GetEnvFileValue(Content, 'RDCB_SERVER');
  if Val <> '' then ServersPage.Values[0] := Val;
end;

(* ================================================================= *)
(* PAGINAS DEL WIZARD                                                 *)
(* ================================================================= *)
procedure InitializeWizard;
var
  AccountStr: String;
begin
  AccountStr := GetEnv('USERDOMAIN') + '\' + GetEnv('USERNAME');

  { -- Pagina 1: Credenciales del servicio Windows (NSSM) -- }
  CredPage := CreateInputQueryPage(
    wpSelectComponents,
    ExpandConstant('{cm:CredTitle}'),
    ExpandConstant('{cm:CredDescription}'),
    ExpandConstant('{cm:CredAccount}') + ' ' + AccountStr
  );
  CredPage.Add(ExpandConstant('{cm:CredPassword}'), True);

  { -- Pagina 2: Active Directory / LDAP -- }
  ADPage := CreateInputQueryPage(
    CredPage.ID,
    ExpandConstant('{cm:ADTitle}'),
    ExpandConstant('{cm:ADDescription}'),
    ''
  );
  ADPage.Add(ExpandConstant('{cm:ADLdapUrl}'), False);
  ADPage.Add(ExpandConstant('{cm:ADBaseDN}'), False);
  ADPage.Add(ExpandConstant('{cm:ADDomain}'), False);
  ADPage.Add(ExpandConstant('{cm:ADServiceUser}'), False);
  ADPage.Add(ExpandConstant('{cm:ADServicePass}'), True);

  { Valores auto-detectados desde el entorno }
  ADPage.Values[0] := AutoDetectLdapUrl;
  ADPage.Values[1] := AutoDetectBaseDN;
  ADPage.Values[2] := GetEnv('USERDOMAIN');

  { -- Pagina 3: Servidores y servicios -- }
  ServersPage := CreateInputQueryPage(
    ADPage.ID,
    ExpandConstant('{cm:SrvTitle}'),
    ExpandConstant('{cm:SrvDescription}'),
    ''
  );
  ServersPage.Add(ExpandConstant('{cm:SrvRDCB}'), False);

  { -- Pagina 4: Certificado SSL -- }
  CertPage := CreateCustomPage(
    ServersPage.ID,
    ExpandConstant('{cm:CertTitle}'),
    ExpandConstant('{cm:CertDescription}')
  );

  { Label }
  with TNewStaticText.Create(CertPage) do
  begin
    Parent   := CertPage.Surface;
    Caption  := ExpandConstant('{cm:CertLabel}');
    Left     := 0;
    Top      := 8;
    Width    := CertPage.SurfaceWidth;
  end;

  { ComboBox para certificados }
  CertCombo := TNewComboBox.Create(CertPage);
  CertCombo.Parent := CertPage.Surface;
  CertCombo.Left   := 0;
  CertCombo.Top    := 28;
  CertCombo.Width  := CertPage.SurfaceWidth;
  CertCombo.Style  := csDropDownList;

  CertCount := 0;
  CertsEnumerated := False;

  EnvLoaded := False;
end;

(* Cargar .env existente al llegar a CredPage, cuando {app} ya esta disponible *)
(* Enumerar certificados SSL al llegar a CertPage *)
procedure CurPageChanged(CurPageID: Integer);
var
  RC: Integer;
  TmpFile, ScriptFile, ScriptContent: String;
  Lines: TArrayOfString;
  I, P: Integer;
  Line: String;
begin
  if (CurPageID = CredPage.ID) and (not EnvLoaded) then
  begin
    LoadExistingEnvValues;
    EnvLoaded := True;
  end;

  { Enumerar certificados SSL la primera vez que se muestra la pagina }
  if (CurPageID = CertPage.ID) and (not CertsEnumerated) then
  begin
    CertsEnumerated := True;
    TmpFile    := ExpandConstant('{tmp}\certs_list.txt');
    ScriptFile := ExpandConstant('{tmp}\enum-certs.ps1');

    ScriptContent :=
      'Get-ChildItem Cert:\LocalMachine\My | ' +
      'Where-Object { $_.HasPrivateKey -and $_.NotAfter -gt (Get-Date) } | ' +
      'ForEach-Object { $_.Thumbprint + [char]124 + $_.Subject + '' (exp: '' + $_.NotAfter.ToString(''yyyy-MM-dd'') + '')'' } | ' +
      'Out-File -Encoding UTF8 ''' + TmpFile + '''';

    SaveStringToFile(ScriptFile, ScriptContent, False);
    Exec('powershell.exe',
      '-ExecutionPolicy Bypass -NoProfile -File "' + ScriptFile + '"',
      '', SW_HIDE, ewWaitUntilTerminated, RC);
    DeleteFile(ScriptFile);

    if FileExists(TmpFile) then
    begin
      if LoadStringsFromFile(TmpFile, Lines) then
      begin
        for I := 0 to GetArrayLength(Lines) - 1 do
        begin
          Line := Trim(Lines[I]);
          if Line <> '' then
          begin
            P := Pos('|', Line);
            if P > 0 then
            begin
              SetArrayLength(CertThumbprints, CertCount + 1);
              CertThumbprints[CertCount] := Copy(Line, 1, P - 1);
              CertCombo.Items.Add(Copy(Line, P + 1, Length(Line)));
              CertCount := CertCount + 1;
            end;
          end;
        end;
      end;
      DeleteFile(TmpFile);
    end;

    if CertCount > 0 then
      CertCombo.ItemIndex := 0;
  end;
end;

(* Ocultar paginas si no se instala el componente correspondiente *)
function ShouldSkipPage(PageID: Integer): Boolean;
begin
  Result := False;
  if (PageID = CredPage.ID) or (PageID = ADPage.ID) or (PageID = ServersPage.ID) then
    Result := not WizardIsComponentSelected('backend');
  if (PageID = CertPage.ID) then
    Result := not WizardIsComponentSelected('frontend');
end;

(* ================================================================= *)
(* VALIDACION DE CREDENCIALES AD (timeout 15 s)                       *)
(* ================================================================= *)
function ValidateCredentials: Integer;
var
  RC: Integer;
  PwdFile, ResultFile, ScriptFile, ScriptContent: String;
  ResText: AnsiString;
begin
  Result := 2;
  PwdFile    := ExpandConstant('{tmp}\svcpwd_validate.dat');
  ResultFile := ExpandConstant('{tmp}\svcpwd_result.dat');
  ScriptFile := ExpandConstant('{tmp}\validate-creds.ps1');

  SaveStringToFile(PwdFile, CredPage.Values[0], False);

  ScriptContent :=
    '$res = 2' + #13#10 +
    'try {' + #13#10 +
    '  $pw = (Get-Content ''' + PwdFile + ''' -Raw).Trim()' + #13#10 +
    '  Remove-Item ''' + PwdFile + ''' -Force -EA SilentlyContinue' + #13#10 +
    '  $d = $env:USERDNSDOMAIN' + #13#10 +
    '  if (-not $d) { $res = 2 }' + #13#10 +
    '  else {' + #13#10 +
    '    $rs = [runspacefactory]::CreateRunspace(); $rs.Open()' + #13#10 +
    '    $ps = [powershell]::Create(); $ps.Runspace = $rs' + #13#10 +
    '    [void]$ps.AddScript({' + #13#10 +
    '      param($domain,$user,$pass)' + #13#10 +
    '      Add-Type -AssemblyName System.DirectoryServices.AccountManagement' + #13#10 +
    '      $c = [System.DirectoryServices.AccountManagement.PrincipalContext]::new(' + #13#10 +
    '        [System.DirectoryServices.AccountManagement.ContextType]::Domain,$domain)' + #13#10 +
    '      $c.ValidateCredentials($user,$pass)' + #13#10 +
    '    }).AddArgument($d).AddArgument($env:USERNAME).AddArgument($pw)' + #13#10 +
    '    $h = $ps.BeginInvoke()' + #13#10 +
    '    if ($h.AsyncWaitHandle.WaitOne(15000)) {' + #13#10 +
    '      $r = $ps.EndInvoke($h)' + #13#10 +
    '      if ($r -and $r[0] -eq $true) { $res = 0 } else { $res = 1 }' + #13#10 +
    '    }' + #13#10 +
    '    try { $ps.Stop() } catch {}' + #13#10 +
    '    $ps.Dispose(); $rs.Dispose()' + #13#10 +
    '  }' + #13#10 +
    '} catch { $res = 2 }' + #13#10 +
    'Remove-Item ''' + PwdFile + ''' -Force -EA SilentlyContinue' + #13#10 +
    '[IO.File]::WriteAllText(''' + ResultFile + ''', $res.ToString())';

  SaveStringToFile(ScriptFile, ScriptContent, False);

  Exec('cmd.exe',
    '/C start /WAIT /B powershell.exe -ExecutionPolicy Bypass -NoProfile -File "' + ScriptFile + '"',
    '', SW_HIDE, ewWaitUntilTerminated, RC);

  if FileExists(ResultFile) then
  begin
    if LoadStringFromFile(ResultFile, ResText) then
    begin
      ResText := Trim(ResText);
      if ResText = '0' then Result := 0
      else if ResText = '1' then Result := 1
      else Result := 2;
    end;
  end;

  DeleteFile(PwdFile);
  DeleteFile(ResultFile);
  DeleteFile(ScriptFile);
end;

(* ================================================================= *)
(* VALIDACION DE PAGINAS                                              *)
(* ================================================================= *)
function NextButtonClick(CurPageID: Integer): Boolean;
var
  ValidationResult, I: Integer;
  AllFilled: Boolean;
begin
  Result := True;

  { -- Credenciales del servicio Windows -- }
  if CurPageID = CredPage.ID then
  begin
    if Trim(CredPage.Values[0]) = '' then
    begin
      MsgBox(ExpandConstant('{cm:CredEmpty}'), mbError, MB_OK);
      Result := False;
      Exit;
    end;

    WizardForm.NextButton.Enabled := False;
    WizardForm.BackButton.Enabled := False;
    WizardForm.CancelButton.Enabled := False;
    try
      ValidationResult := ValidateCredentials;
    finally
      WizardForm.NextButton.Enabled := True;
      WizardForm.BackButton.Enabled := True;
      WizardForm.CancelButton.Enabled := True;
    end;

    if ValidationResult = 1 then
    begin
      MsgBox(ExpandConstant('{cm:CredInvalid}'), mbError, MB_OK);
      Result := False;
    end
    else if ValidationResult = 2 then
      MsgBox(ExpandConstant('{cm:CredDomainWarn}'), mbInformation, MB_OK);
  end;

  { -- Active Directory -- }
  if CurPageID = ADPage.ID then
  begin
    AllFilled := True;
    for I := 0 to 4 do
    begin
      if Trim(ADPage.Values[I]) = '' then
      begin
        AllFilled := False;
        Break;
      end;
    end;
    if not AllFilled then
    begin
      MsgBox(ExpandConstant('{cm:ADFieldsRequired}'), mbError, MB_OK);
      Result := False;
    end;
  end;

  { -- Servidores -- }
  if CurPageID = ServersPage.ID then
  begin
    AllFilled := True;
    for I := 0 to 0 do
    begin
      if Trim(ServersPage.Values[I]) = '' then
      begin
        AllFilled := False;
        Break;
      end;
    end;
    if not AllFilled then
    begin
      MsgBox(ExpandConstant('{cm:SrvFieldsRequired}'), mbError, MB_OK);
      Result := False;
    end;
  end;

  { -- Certificado SSL -- }
  if CurPageID = CertPage.ID then
  begin
    if CertCount = 0 then
    begin
      MsgBox(ExpandConstant('{cm:CertNone}'), mbError, MB_OK);
      Result := False;
    end
    else if CertCombo.ItemIndex < 0 then
    begin
      MsgBox(ExpandConstant('{cm:CertEmpty}'), mbError, MB_OK);
      Result := False;
    end;
  end;
end;

(* ================================================================= *)
(* ARCHIVOS DE CONFIGURACION                                          *)
(* ================================================================= *)
procedure SavePasswordToFile;
begin
  SaveStringToFile(ExpandConstant('{tmp}\svcpwd.dat'), CredPage.Values[0], False);
end;

procedure WriteEnvFile;
var
  EnvPath, JwtSecret, Content: String;
  ExistingContent: AnsiString;
begin
  EnvPath := ExpandConstant('{app}\backend\.env');

  { Preservar JWT_SECRET en upgrades; generar nuevo en primera instalacion }
  JwtSecret := '';
  if FileExists(EnvPath) then
  begin
    if LoadStringFromFile(EnvPath, ExistingContent) then
    begin
      JwtSecret := GetEnvFileValue(ExistingContent, 'JWT_SECRET');
      if JwtSecret = 'cambia_esto_por_un_secreto_muy_largo_y_aleatorio_en_produccion' then
        JwtSecret := '';
    end;
  end;
  if JwtSecret = '' then
    JwtSecret := GenerateRandomHex(64);

  Content :=
    '# ============================================================' + #13#10 +
    '#  RDWeb Portal - Server configuration' + #13#10 +
    '#  Generated by installer v' + '{#SetupSetting("AppVersion")}' + #13#10 +
    '# ============================================================' + #13#10 + #13#10 +
#if BackendType == "python"
    '# --- FastAPI Server ---' + #13#10 +
#else
    '# --- Express Server ---' + #13#10 +
#endif
    'PORT=3000' + #13#10 +
    'NODE_ENV=production' + #13#10 + #13#10 +
    '# --- JWT ---' + #13#10 +
    'JWT_SECRET=' + JwtSecret + #13#10 +
    'JWT_EXPIRES_IN=1h' + #13#10 + #13#10 +
    '# --- Active Directory / LDAP ---' + #13#10 +
    'LDAP_URL=' + ADPage.Values[0] + #13#10 +
    'LDAP_BASE_DN=' + ADPage.Values[1] + #13#10 +
    'AD_DOMAIN=' + ADPage.Values[2] + #13#10 +
    'AD_SERVICE_USER=' + ADPage.Values[3] + #13#10 +
    'AD_SERVICE_PASS=' + ADPage.Values[4] + #13#10 + #13#10 +
    '# --- RD Connection Broker ---' + #13#10 +
    'RDCB_SERVER=' + ServersPage.Values[0] + #13#10 + #13#10 +
    '# --- RDP ---' + #13#10 +
    'RDP_GATEWAY_CREDENTIAL_SOURCE=0' + #13#10 +
    'RDP_PROMPT_CREDENTIAL_ONCE=true' + #13#10 +
    'RDP_PROMPT_FOR_CREDENTIALS_ON_CLIENT=true' + #13#10 +
    'RDP_USE_MULTIMON=false' + #13#10 +
    'RDP_SPAN_MONITORS=false' + #13#10 + #13#10 +
    '# --- Simulation Mode ---' + #13#10 +
    'SIMULATION_MODE=false' + #13#10;

  SaveStringToFile(EnvPath, Content, False);
end;

(* ================================================================= *)
(* PREPARACION E INSTALACION                                          *)
(* ================================================================= *)
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

procedure CurStepChanged(CurStep: TSetupStep);
var
  RC: Integer;
  LogDir: String;
begin
  if CurStep = ssInstall then
  begin
    if WizardIsComponentSelected('backend') then
      SavePasswordToFile;
  end;

  if CurStep = ssPostInstall then
  begin
    LogDir := ExpandConstant('{app}\backend\logs');
    ForceDirectories(LogDir);

    { -- Generar .env con los valores del wizard -- }
    if WizardIsComponentSelected('backend') then
      WriteEnvFile;

    { -- Prerrequisitos IIS -- }
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

    { -- Servicio Backend -- }
    if WizardIsComponentSelected('backend') then
    begin
      WizardForm.StatusLabel.Caption := ExpandConstant('{cm:StatusService}');
      if not Exec('powershell.exe',
        ExpandConstant('-ExecutionPolicy Bypass -NoProfile -File "{tmp}\setup-backend-service.ps1"' +
          ' -BackendDir "{app}\backend"' +
          ' -ServiceName "{#ServiceName}"' +
          ' -BackendType "{#BackendType}"' +
          ' -PasswordFile "{tmp}\svcpwd.dat"' +
          ' -LogFile "{app}\backend\logs\install-service.log"'),
        '', SW_HIDE, ewWaitUntilTerminated, RC) or (RC <> 0) then
      begin
        MsgBox(FmtMessage(ExpandConstant('{cm:ErrService}'), [LogDir]), mbError, MB_OK);
      end;
    end;

    { -- Sitio IIS (HTTPS + Reverse Proxy) -- }
    if WizardIsComponentSelected('frontend') and (CertCount > 0) and (CertCombo.ItemIndex >= 0) then
    begin
      WizardForm.StatusLabel.Caption := ExpandConstant('{cm:StatusIISSite}');
      if not Exec('powershell.exe',
        ExpandConstant('-ExecutionPolicy Bypass -NoProfile -File "{tmp}\setup-iis-site.ps1"' +
          ' -SiteName "{#MyAppName}"' +
          ' -FrontendDir "{app}\frontend"' +
          ' -CertThumbprint "') + CertThumbprints[CertCombo.ItemIndex] +
          ExpandConstant('" -LogFile "{app}\backend\logs\install-iis-site.log"'),
        '', SW_HIDE, ewWaitUntilTerminated, RC) or (RC <> 0) then
      begin
        MsgBox(FmtMessage(ExpandConstant('{cm:ErrIISSite}'), [LogDir]), mbError, MB_OK);
      end;
    end;

    MsgBox(ExpandConstant('{cm:DoneReminder}'), mbInformation, MB_OK);
  end;
end;

(* ================================================================= *)
(* LIMPIEZA                                                           *)
(* ================================================================= *)
procedure DeinitializeSetup;
var
  PwdFile: String;
begin
  PwdFile := ExpandConstant('{tmp}\svcpwd.dat');
  if FileExists(PwdFile) then
    DeleteFile(PwdFile);
end;
