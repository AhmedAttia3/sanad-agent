; Installer for Sanad
; Built with NSIS

!include "MUI2.nsh"
!include "x64.nsh"

; General
Name "Sanad"
OutFile "..\..\build\sanad-client-setup.exe"
InstallDir "$PROGRAMFILES\Sanad"
InstallDirRegKey HKCU "Software\Sanad" "Install_Dir"

RequestExecutionLevel admin

; MUI Settings
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_LANGUAGE "English"
!insertmacro MUI_LANGUAGE "Arabic"

; Installer sections
Section "Install"
  SetOutPath "$INSTDIR"
  
  ; Copy main executable
  File "..\..\build\windows\x64\runner\Release\sanad-client.exe"
  
  ; Copy DLL files
  File "..\..\build\windows\x64\runner\Release\*.dll"
  
  ; Copy data folder
  SetOutPath "$INSTDIR\data"
  File /r "..\..\build\windows\x64\runner\Release\data\*"
  
  ; Install Visual C++ Redistributable
  SetOutPath "$TEMP"
  File "..\..\build\windows\x64\runner\Release\vc_redist.x64.exe"
  DetailPrint "Installing Microsoft Visual C++ Redistributable..."
  ExecWait '"$TEMP\vc_redist.x64.exe" /install /quiet /norestart'
  Delete "$TEMP\vc_redist.x64.exe"
  SetOutPath "$INSTDIR"
  
  ; Create start menu shortcuts
  SetOutPath "$INSTDIR"
  CreateDirectory "$SMPROGRAMS\Sanad"
  CreateShortcut "$SMPROGRAMS\Sanad\Sanad.lnk" "$INSTDIR\sanad-client.exe"
  CreateShortcut "$SMPROGRAMS\Sanad\Uninstall.lnk" "$INSTDIR\uninstall.exe"
  
  ; Create desktop shortcut
  CreateShortcut "$DESKTOP\Sanad.lnk" "$INSTDIR\sanad-client.exe"
  
  ; Create uninstaller
  WriteUninstaller "$INSTDIR\uninstall.exe"
  
  ; Store installation folder
  WriteRegStr HKCU "Software\Sanad" "Install_Dir" "$INSTDIR"
SectionEnd

; Uninstaller section
Section "Uninstall"
  ; Remove shortcuts
  RMDir /r "$SMPROGRAMS\Sanad"
  Delete "$DESKTOP\Sanad.lnk"
  
  ; Remove application files
  RMDir /r "$INSTDIR"
  
  ; Remove registry entries
  DeleteRegKey HKCU "Software\Sanad"
SectionEnd

; Function to ensure admin rights
Function .onInit
  ${If} ${RunningX64}
    SetRegView 64
  ${EndIf}
FunctionEnd
