@echo off
setlocal
set "REPO_ROOT=%~dp0..\.."
if not exist "%REPO_ROOT%\node_modules\zod" (
  echo Error: node_modules missing in "%REPO_ROOT%" ^(run: vp -C "%REPO_ROOT%" install^) 1>&2
  exit /b 1
)
vpx "%REPO_ROOT%\cli\src\main.ts" "mkclp" %*
