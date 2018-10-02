del *.vsix
if not x%1 == x/b powershell BumpTaskVersion.ps1 -Folder src\TFVCGet & powershell BumpExtVersion.ps1 -File src\ext.json
call %APPDATA%\npm\tfx extension create --manifest-globs ext.json --root src
