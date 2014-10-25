:: Assumption - kudu will detect web app and set this to the correct subfolder?
SET DEPLOYMENT_SOURCE=%~dp0%WebApplication1
:: Assumption - the latest kudusync with the file-move-delete logic will be on the server?
SET KUDU_SYNC_CMD=%~dp0%build\kudusync.cmd

:: -- cut mark -- ::

@if "%SCM_TRACE_LEVEL%" NEQ "4" @echo off

:: ----------------------
:: KUDU Deployment Script
:: Version: 0.1.11
:: ----------------------

:: Prerequisites
:: -------------

:: Verify node.js installed
where node 2>nul >nul
IF %ERRORLEVEL% NEQ 0 (
  echo Missing node.js executable, please install node.js, if already installed make sure it can be reached from current environment.
  goto error
)

:: Setup
:: -----

setlocal enabledelayedexpansion

IF NOT DEFINED DEPLOYMENT_TEMP (
  SET ARTIFACTS=%~dp0%..\artifacts
) ELSE (
  SET ARTIFACTS=%HOMEDRIVE%%HOMEPATH%\artifacts
)

SET ARTIFACTS_OUT=%ARTIFACTS%\publish

IF NOT DEFINED DEPLOYMENT_SOURCE (
  SET DEPLOYMENT_SOURCE=%~dp0%.
)

IF NOT DEFINED DEPLOYMENT_TARGET (
  SET DEPLOYMENT_TARGET=%ARTIFACTS%\output
)

IF NOT DEFINED NEXT_MANIFEST_PATH (
  SET NEXT_MANIFEST_PATH=%ARTIFACTS%\manifest

  IF NOT DEFINED PREVIOUS_MANIFEST_PATH (
    SET PREVIOUS_MANIFEST_PATH=%ARTIFACTS%\manifest
  )
)

:: Remove wwwroot if deploying to default location
IF "%DEPLOYMENT_TARGET%" == "%WEBROOT_PATH%" (
  FOR /F %%i IN ("%DEPLOYMENT_TARGET%") DO IF "%%~nxi"=="wwwroot" (
    SET DEPLOYMENT_TARGET=%%~dpi
  )
)

:: Remove trailing slash if present
IF "%DEPLOYMENT_TARGET:~-1%"=="\" (
  SET DEPLOYMENT_TARGET=%DEPLOYMENT_TARGET:~0,-1%
)

IF NOT DEFINED KUDU_SYNC_CMD (
  :: Install kudu sync
  echo Installing Kudu Sync
  call npm install kudusync -g --silent
  IF !ERRORLEVEL! NEQ 0 goto error

  :: Locally just running "kuduSync" would also work
  SET KUDU_SYNC_CMD=%appdata%\npm\kuduSync.cmd
)

IF NOT DEFINED KRE_VERSION (
  SET KRE_VERSION=1.0.0-beta2-10614
)

::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: Deployment
:: ----------

echo Handling Basic ASP.NET 5 Web Application deployment.

:: 1. Download KRE
CALL  kvm install %KRE_VERSION% -x86 -runtime CLR %KVM_INSTALL_OPTIONS%
IF !ERRORLEVEL! NEQ 0 goto error

:: 2. Restore dependencies
CALL  kpm restore %DEPLOYMENT_SOURCE% %KPM_RESTORE_OPTIONS%
IF !ERRORLEVEL! NEQ 0 goto error

:: 3. Package web application
RMDIR /S /Q "%ARTIFACTS_OUT%"
CALL  kpm pack %DEPLOYMENT_SOURCE% --out "%ARTIFACTS_OUT%" --runtime %USERPROFILE%\.kre\packages\KRE-CLR-x86.%KRE_VERSION% %KPM_PACK_OPTIONS%
IF !ERRORLEVEL! NEQ 0 goto error

:: 4. KuduSync
CALL :ExecuteCmd "%KUDU_SYNC_CMD%" -v 5000 -f "%ARTIFACTS_OUT%" -t "%DEPLOYMENT_TARGET%" -n "%NEXT_MANIFEST_PATH%" -p "%PREVIOUS_MANIFEST_PATH%"
IF !ERRORLEVEL! NEQ 0 goto error

:: 5. Request homepage
IF "%WEBSITE_HOSTNAME%" NEQ "" (
  echo ==== http://%WEBSITE_HOSTNAME% ====
  curl --silent --show-error http://%WEBSITE_HOSTNAME% 
  echo.
  echo ========
)

::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

:: Post deployment stub
IF DEFINED POST_DEPLOYMENT_ACTION call "%POST_DEPLOYMENT_ACTION%"
IF !ERRORLEVEL! NEQ 0 goto error

goto end

:: Execute command routine that will echo out when error
:ExecuteCmd
setlocal
set _CMD_=%*
call %_CMD_%
if "%ERRORLEVEL%" NEQ "0" echo Failed exitCode=%ERRORLEVEL%, command=%_CMD_%
exit /b %ERRORLEVEL%

:error
endlocal
echo An error has occurred during web site deployment.
call :exitSetErrorLevel
call :exitFromFunction 2>nul

:exitSetErrorLevel
exit /b 1

:exitFromFunction
()

:end
endlocal
echo Finished successfully.
