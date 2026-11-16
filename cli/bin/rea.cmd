@echo off
setlocal
set "REPO_ROOT=%~dp0..\.."
set "VPX_BIN="
for /f "delims=" %%I in ('where vpx 2^>nul') do (
  set "VPX_BIN=%%I"
  goto :found_vpx
)
if defined VP_HOME (
  if exist "%VP_HOME%\bin\vpx.exe" set "VPX_BIN=%VP_HOME%\bin\vpx.exe"
  if not defined VPX_BIN if exist "%VP_HOME%\bin\vpx.cmd" set "VPX_BIN=%VP_HOME%\bin\vpx.cmd"
)
if not defined VPX_BIN (
  if exist "%USERPROFILE%\.vite-plus\bin\vpx.exe" set "VPX_BIN=%USERPROFILE%\.vite-plus\bin\vpx.exe"
  if not defined VPX_BIN if exist "%USERPROFILE%\.vite-plus\bin\vpx.cmd" set "VPX_BIN=%USERPROFILE%\.vite-plus\bin\vpx.cmd"
)
if not defined VPX_BIN (
  echo Error: vpx not found. Install Vite+ first. 1>&2
  exit /b 127
)
:found_vpx
if not exist "%REPO_ROOT%\node_modules\zod" (
  echo Error: node_modules missing in "%REPO_ROOT%" ^(run: vp -C "%REPO_ROOT%" install^) 1>&2
  exit /b 1
)
"%VPX_BIN%" "%REPO_ROOT%\cli\src\main.ts" "rea" %*
