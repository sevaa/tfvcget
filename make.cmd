rem run with /b to prevent automatic version bumping

del *.vsix
rem The Powershell files should be in path!!!
if not x%1 == x/b set OPT=--rev-version
if not exist %APPDATA%\npm\azp-task-bump.cmd npm i -g azp-task-bump
if not x%1 == x/b azp-task-bump src\TFVCGet
call %APPDATA%\npm\tfx extension create %OPT% --manifest-globs ext.json --root src
