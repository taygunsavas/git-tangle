@echo off
setlocal EnableExtensions

set "BASH_EXE="
set "PATH_BASH="

if exist "%ProgramFiles%\Git\bin\bash.exe" set "BASH_EXE=%ProgramFiles%\Git\bin\bash.exe"
if not defined BASH_EXE if exist "%ProgramFiles%\Git\usr\bin\bash.exe" set "BASH_EXE=%ProgramFiles%\Git\usr\bin\bash.exe"
if not defined BASH_EXE if exist "%ProgramFiles(x86)%\Git\bin\bash.exe" set "BASH_EXE=%ProgramFiles(x86)%\Git\bin\bash.exe"
if not defined BASH_EXE if exist "%ProgramFiles(x86)%\Git\usr\bin\bash.exe" set "BASH_EXE=%ProgramFiles(x86)%\Git\usr\bin\bash.exe"

if not defined BASH_EXE (
  for %%I in (bash.exe) do (
    if not defined PATH_BASH set "PATH_BASH=%%~$PATH:I"
  )
  if defined PATH_BASH if /I not "%PATH_BASH%"=="%SystemRoot%\System32\bash.exe" set "BASH_EXE=%PATH_BASH%"
)

if not defined BASH_EXE (
  echo [tangle] ERROR: Git Bash was not found. Install Git for Windows first. 1>&2
  exit /b 1
)

set "ENTRY=%~dp0bin\git-tangle"
set "ENTRY=%ENTRY:\=/%"

"%BASH_EXE%" "%ENTRY%" %*
exit /b %ERRORLEVEL%
