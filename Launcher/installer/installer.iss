#define MyAppName "KYBER Launcher"
#define MyAppVersion "2.0.0"
#define MyAppPublisher "ArmchairDevelopers"
#define MyAppURL "https://kyber.gg"
#define AppId "KyberLauncher"
#define MyAppExeName "kyber_launcher.exe"

[Dirs]
Name: "{commonappdata}\Kyber"; Permissions: users-modify
Name: "{commonappdata}\Kyber\Module"; Permissions: users-modify

[Setup]
AppId={#AppId}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
VersionInfoProductName=KYBER
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DisableProgramGroupPage=yes
SetupIconFile=../windows/runner/resources/app_icon.ico
OutputDir=./
OutputBaseFilename=KyberLauncherInstaller
Compression=lzma
SolidCompression=yes
DisableWelcomePage=no
WizardStyle=modern

[Registry]
Root: HKCR; Subkey: ".kbcollection"; ValueType: string; ValueName: ""; ValueData: "{#AppId}.kmodfile"; Flags: uninsdeletevalue
Root: HKCR; Subkey: "{#AppId}.kbcollection"; ValueType: string; ValueName: ""; ValueData: "Kyber Collection File"; Flags: uninsdeletekey
Root: HKCR; Subkey: "{#AppId}.kbcollection\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#MyAppExeName},0"; Flags: uninsdeletekey
Root: HKCR; Subkey: "{#AppId}.kbcollection\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""; Flags: uninsdeletekey

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "7za.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\third_party\libs\7z.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\third_party\libs\UnRAR.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "vc_redist.x64.exe"; DestDir: "{tmp}"; Flags: dontcopy

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; AppUserModelID: "kyber.LAUNCHER"; AppUserModelToastActivatorCLSID: "B784B1A4-D682-4FE6-BDBA-21EDDAE42791"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall
//filename: "{tmp}\VC_redist.x64.exe"; \
//f StatusMsg: "Installing VC++ Redistributables..."; \
//f Parameters: "/q /norestart"; Check: VC2017RedistNeedsInstall; Flags: waituntilterminated

[Code]
const
  CppRedistKey64 = 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\X64';
  RequiredMajorVersion = 14;
  RequiredMinorVersion = 42;
  RequiredBuildVersion = 34433;
  
function StrSplit(Text: String; Separator: String): TArrayOfString;
var
  i, p: Integer;
  Dest: TArrayOfString; 
begin
  i := 0;
  repeat
    SetArrayLength(Dest, i+1);
    p := Pos(Separator,Text);
    if p > 0 then begin
      Dest[i] := Copy(Text, 1, p-1);
      Text := Copy(Text, p + Length(Separator), Length(Text));
      i := i + 1;
    end else begin
      Dest[i] := Text;
      Text := '';
    end;
  until Length(Text)=0;
  Result := Dest
end;
  
function IsCppRedistLatestInstalled: Boolean;
var
  InstalledVersion: string;
  InstalledMajor, InstalledMinor, InstalledBuild: Integer;
  VersionParts: TArrayOfString;
begin
  Result := False;
  if RegQueryStringValue(HKLM64, CppRedistKey64, 'Version', InstalledVersion) then
  begin
    Log('Found installed version: ' + InstalledVersion);
    if Copy(InstalledVersion, 1, 1) = 'v' then
      Delete(InstalledVersion, 1, 1);

    VersionParts := StrSplit(InstalledVersion, '.');
    if Length(VersionParts) < 3 then
    begin
      Log('Version format is invalid.');
      Exit;
    end;

    try
      InstalledMajor := StrToInt(VersionParts[0]);
      InstalledMinor := StrToInt(VersionParts[1]);
      InstalledBuild := StrToInt(VersionParts[2]);
      if (InstalledMajor > RequiredMajorVersion) or
         ((InstalledMajor = RequiredMajorVersion) and (InstalledMinor > RequiredMinorVersion)) or
         ((InstalledMajor = RequiredMajorVersion) and (InstalledMinor = RequiredMinorVersion) and (InstalledBuild >= RequiredBuildVersion)) then
      begin
        Result := True;
        Log('Visual C++ Redistributable is up-to-date.');
      end
      else
        Log('Installed version is outdated.');
    except
      Log('Error parsing version number.');
    end;
  end
  else
    Log('Visual C++ Redistributable not found in registry.');
end;

procedure InstallCppRedist;
var
  ResultCode: Integer;
begin
  if Exec(ExpandConstant('{tmp}\VC_redist.x64.exe'), '/quiet /norestart', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
  begin
    if ResultCode = 0 then
      Log('Visual C++ Redistributable installed successfully.')
    else
      MsgBox('Failed to install Visual C++ Redistributable. Error code: ' + IntToStr(ResultCode), mbError, MB_OK);
  end
  else
    MsgBox('Failed to execute Visual C++ Redistributable installer.', mbError, MB_OK);
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  ResultCode: Integer;
begin
  if CurStep = ssPostInstall then
  begin
    Log('Checking for Visual C++ Redistributable...');
    if not IsCppRedistLatestInstalled then
    begin
      Log('Visual C++ Redistributable is not up-to-date. Extracting and installing...');
      ExtractTemporaryFile('vc_redist.x64.exe');
      if Exec(ExpandConstant('{tmp}\vc_redist.x64.exe'), '/quiet /norestart', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
      begin
        if ResultCode = 0 then
          Log('Visual C++ Redistributable installed successfully.')
        else
          Log('Visual C++ Redistributable installation failed with error code: ' + IntToStr(ResultCode));
      end
      else
        Log('Failed to execute Visual C++ Redistributable installer.');
    end
    else
      Log('Visual C++ Redistributable is already up-to-date.');
  end;
end;