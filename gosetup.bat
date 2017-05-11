@rem Copyright (C) 2012-2017 Kody Brown.
@rem Released under the MIT License.

@echo off

:init
    where /Q go.exe
    if %errorlevel% NEQ 0 goto :GoNotFound

    call :CleanupPath
    call :InsertPath "C:\Windows\System32"
    if exist "C:\Bin" call :InsertPath "C:\Bin"

:parse

:main
    call PrintOutput {Header} Setting up the project environment
    echo.

    REM Clear all of these out (Go 1.2+ no longer requires them)
    set "GOARCH="
    set "GOOS="
    set "GOBIN="
    set "GOROOT="
    set "GOPATH="

    :: Set the GOPATH.
    pushd "..\..\..\.."

    :: Ensure we are in a valid Go project directory structure.
    if not exist "%CD%\bin" echo The `bin` directory in the GOPATH was not found! & popd & goto :end
    if not exist "%CD%\src" echo The `src` directory in the GOPATH was not found! Are you in the correct directory? & popd & goto :end

    call :InsertPath "%CD%\bin"
    set "GOPATH=%CD%"
    popd

    :: Ensure the user's GOPATH/bin is in the PATH.
    call :AppendPath "%AppData%\Go\bin"

    :: Output the Go location
    call PrintOutput {Highlight} Go location:
    for /F "tokens=*" %%G in ('where go.exe') do (
        echo.  %%G
    )
    echo.

    :: Display Go version.
    call PrintOutput {Highlight} Go version:
    for /F "tokens=1,2,*" %%G in ('go version') do (
        echo.  %%I
    )
    echo.

    :: Display Go environment variables.
    call PrintOutput {Highlight} Go environment variables:
    setlocal EnableDelayedExpansion
    for /F "tokens=*" %%G in ('set GO') do (
        set "__G=%%G"
        if not "!__G:~0,14!"=="GOOGLE_API_KEY" (
            echo.  %%G
        )
    )
    endlocal
    echo.

    goto :end

:end
    call :cleanup
    exit /B

:cleanup
    :: Clean up the environment; delete 
    :: any temporary variables, etc.
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
