@rem Copyright (C) 2012-2017 Kody Brown.
@rem Released under the MIT License.

@setlocal EnableDelayedExpansion
@echo off

:init
    where /Q go.exe
    if %errorlevel% NEQ 0 goto :GoNotFound

    REM 
    REM Set up the environment and files..
    REM 

    REM Clear all of these out (Go 1.2+ no longer requires them)
    set "GOARCH="
    set "GOOS="
    set "GOBIN="
    set "GOROOT="
    set "GOPATH="

    set "OptOldVersionFile="

    :: Set the GOPATH.
    pushd "..\..\..\.."

    :: Ensure we are in a valid Go project directory structure.
    if not exist "%CD%\bin" echo The `bin` directory in the GOPATH was not found! & popd & goto :end
    if not exist "%CD%\src" echo The `src` directory in the GOPATH was not found! Are you in the correct directory? & popd & goto :end

    call :InsertPath "%CD%\bin"
    REM set "GOPATH=%CD%;%AppData%\Go"
    set "GOPATH=%CD%"
    popd

    :: Ensure the user's GOPATH/bin is in the PATH.
    call :AppendPath "%AppData%\Go\bin"

    if not exist "%CD%\.version" echo the `.version` file is missing. & goto :end
    set /P _buildVersion=<"%CD%\.version"
    rem Trim the value read from the file
    for /f "tokens=* delims= " %%a in ("!_buildVersion!") do set "_buildVersion=%%a"
    for /l %%i in (1,1,31) do if "!_buildVersion:~-1!"==" " set "_buildVersion=!_buildVersion:~0,-1!"

    if not exist "%CD%\.name" echo the `.name` file is missing. & goto :end
    set /P _name=<"%CD%\.name"
    rem Trim the value read from the file
    for /f "tokens=* delims= " %%a in ("!_name!") do set "_name=%%a"
    for /l %%i in (1,1,31) do if "!_name:~-1!"==" " set "_name=!_name:~0,-1!"

    call PrintOutput {Header} Building %_name%

    set "_curfile=%~dpnx0"
    set "_specified="

    set "_publish="
    set "_distpath=%UserProfile%\Source\Releases\%_name%"

    set "_time=%TIME%"
    if "%_time:~0,1%"==" " set "_time=0%_time:~1%"
    set "_buildDate=%date:~10,4%-%date:~4,2%-%date:~7,2% %_time:~0,2%:%_time:~3,2%:%_time:~6,2%"
    set "_buildString=v!_buildVersion!.%date:~12,4%%date:~4,2%%date:~7,2%.%_time:~0,2%%_time:~3,2%"
    set "_pubBuildString=v!_buildVersion!.%date:~12,4%%date:~4,2%%date:~7,2%"

    :: Create build/build.go file.
    echo.package build>build\build.go
    echo.>>build\build.go
    echo.// Do not change anything in this file,>>build\build.go
    echo.// as it is overwritten during each build.>>build\build.go
    echo.>>build\build.go
    echo.// Date represents the date and time the app was built.>>build\build.go
    echo.var Date = "%_buildDate%">>build\build.go
    echo.>>build\build.go
    echo.// ShortVersion is the major.minor version.>>build\build.go
    echo.var ShortVersion = "!_buildVersion!">>build\build.go
    echo.>>build\build.go
    echo.// FullVersion is the full version: `major.minor.date.time`.>>build\build.go
    echo.var FullVersion = "%_buildString%">>build\build.go
    echo.>>build\build.go

    echo  buildDate: %_buildDate%
    echo  buildString: %_buildString%

    echo.

    rem GO flags:
    set "_rebuildPkgs="

    if "%~1"==""                call :do_windows & goto :end

:parse
    if "%~1"==""                goto :main

    if /i "%~1"=="-all"         goto :main
    if /i "%~1"=="--all"        goto :main
    if /i "%~1"=="all"          goto :main

    if /i "%~1"=="-publish"     set "_publish=yes" & shift & goto :parse
    if /i "%~1"=="--publish"    set "_publish=yes" & shift & goto :parse
    if /i "%~1"=="-p"           set "_publish=yes" & shift & goto :parse
    if /i "%~1"=="-pub"         set "_publish=yes" & shift & goto :parse

    rem GO flags
    if /i "%~1"=="-a"           set "_rebuildPkgs=yes" & shift & goto :parse
    if /i "%~1"=="-rebuild"     set "_rebuildPkgs=yes" & shift & goto :parse

    findstr /R /I /B /C:"^:do_%~1" "%_curfile%" >NUL 2>&1
    if %errorlevel% EQU 0 (
        set "_specified=yes"
        call :do_%~1
    ) else (
        echo Could not find target: %~1
        goto :end
    )

    shift
    goto :parse

:main
    if defined _specified goto :end

    REM Build each platform
    call :do_windows
    call :do_raspi
    call :do_linux
    call :do_darwin

:end
    endlocal
    exit /B

:build_it
    set "_platform=%~1"
    set "_dir=..\..\..\..\bin\%~1"

    set "tmpfile=%TEMP%\%RANDOM%_build.log"

    set "_ext="
    if /i "%~1"=="windows_amd64" set "_ext=.exe"

    if exist "%_name%%_ext%" del /F /Q "%_name%%_ext%"

    rem GO flags/options:
    set "opts="
    if defined _rebuildPkgs (
        echo  rebuilding all packages..
        set "opts=-a !opts!"
    )

    REM GO ldflags
    REM   -s --> remove debug symols (makes a smaller binary)
    set "ldflags="
    if defined _publish (
        set "ldflags=-ldflags "-s""
    )

    rem go build -ldflags "-X main.buildVersion=!_buildVersion! -X main.buildDate=%_buildDate%" all
    rem go build -ldflags "-X main.buildDate=%_buildDate%" all

    go build !ldflags! !opts! -o %_name%%_ext% >"%tmpfile%"

    if exist "%tmpfile%" (
        set /P build_result=<"%tmpfile%"
        if defined build_result if not "%build_result%"=="" (
            call PrintOutput.cmd "{Error}" "build failed"
            exit /B
        )
        del /F /Q "%tmpfile%"
    )
    set "tmpfile="

    if exist "%_name%%_ext%" echo  build succeeded..
    if not exist "%_name%%_ext%" echo  BUILD FAILED.. & goto :eof

    if not exist "%_dir%" mkdir "%_dir%"
    move /Y "%_name%%_ext%" "%_dir%" >NUL

    if defined _publish (
        echo  tagging file..
        copy /B /V /Y "%_dir%\%_name%%_ext%" "%_dir%\%_name%-%_pubBuildString%%_ext%" >NUL

        if exist "%_distpath%" (
            echo  publishing to salt server..
            if not exist "%_distpath%\%_platform%" mkdir "%_distpath%\%_platform%"
            copy /B /V /Y /D "%_dir%\%_name%%_ext%" "%_distpath%\%_platform%\%_name%%_ext%" >NUL
            copy /B /V /Y /D "%_dir%\%_name%%_ext%" "%_distpath%\%_platform%\%_name%-%_pubBuildString%%_ext%" >NUL
        )
    )

    goto :eof

:do_windows
:do_windows_x64
:do_win
    call PrintOutput {Highlight} building windows:
    set "GOOS=windows"
    set "GOARCH=amd64"
    call :build_it "%GOOS%_%GOARCH%"
    goto :eof

:do_linux
:do_linux_x64
    call PrintOutput {Highlight} building linux:
    set "GOOS=linux"
    set "GOARCH=amd64"
    call :build_it "%GOOS%_%GOARCH%"
    goto :eof

:do_raspi
:do_raspi_x64
:do_rpi
    call PrintOutput {Highlight} building raspi:
    set "GOOS=linux"
    set "GOARCH=arm"
    call :build_it "%GOOS%_%GOARCH%"
    goto :eof

:do_darwin
:do_darwin_x64
:do_mac
:do_macos
:do_osx
    call PrintOutput {Highlight} building darwin:
    set "GOOS=darwin"
    set "GOARCH=amd64"
    call :build_it "%GOOS%_%GOARCH%"
    goto :eof


:GoNotFound
    echo **** ERROR:
    echo      Go was not found in the path.
    call :cleanup
    exit /B 1

:CleanupPath
    where /Q pathx
    if %errorlevel% EQU 0 call pathx --cleanup
    goto :eof

:AppendPath
    where /Q pathx
    if %errorlevel% EQU 0 call pathx --append "%~1"
    if %errorlevel% NEQ 0 set "PATH=%PATH%;%~1"
    goto :eof

:InsertPath
    where /Q pathx
    if %errorlevel% EQU 0 call pathx --insert "%~1"
    if %errorlevel% NEQ 0 set "PATH=%~1;%PATH%"
    goto :eof
