@echo off

set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if not exist "%VSWHERE%" (
	echo ---------------------
    echo ERROR: vswhere.exe was not found. Is Visual Studio installed?
	echo ---------------------
    exit /b 1
)

for /f "usebackq tokens=*" %%i in (`"%VSWHERE%" -prerelease -latest -products * -requires Microsoft.Component.MSBuild -property installationPath`) do (
  set "VcInstallDir=%%i"
)

SET "VsBuildDir=%VcInstallDir%\MSBuild\15.0"
@IF EXIST "%VcInstallDir%\MSBuild\Current" SET VsBuildDir=%VcInstallDir%\MSBuild\Current

"%VsBuildDir%\Bin\MSBuild.exe" %*
