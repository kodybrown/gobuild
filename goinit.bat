@rem Copyright (C) 2012-2017 Kody Brown.
@rem Released under the MIT License.

@setlocal EnableDelayedExpansion
@echo off

:init
    set "cur_file=%~dpnx0"
    set "cur_name=%~n0"
    set "cur_path=%~dp0"

    set "friendly_name=Unknown User"
    set "user_name=unknown"
    set "user_email=someone@unknown.com"

    if exist "%~dp0\.git-user"     set /P friendly_name=<%~dp0\.git-user
    if exist "%~dp0\.git-username" set /P user_name=<%~dp0\.git-username
    if exist "%~dp0\.git-email"    set /P user_email=<%~dp0\.git-email

    set "proj_name="
    set "proj_title="
    set "proj_path="
    set "proj_version="
    set "proj_repo="

    set "OptForceOverwrite="

:parse
    if "%~1"=="" goto :main

    if "%~1"=="/?"           call :ShowHelp & endlocal & goto :end
    if "%~1"=="-help"        call :ShowHelp & endlocal & goto :end
    if "%~1"=="--help"       call :ShowHelp & endlocal & goto :end

    if "%~1"=="-force"       set "OptForceOverwrite=yes" & shift & goto :parse
    if "%~1"=="--force"      set "OptForceOverwrite=yes" & shift & goto :parse
    if "%~1"=="-f"           set "OptForceOverwrite=yes" & shift & goto :parse
    if "%~1"=="/f"           set "OptForceOverwrite=yes" & shift & goto :parse

    if "%~1"=="-name"        set "proj_name=%~2"     & shift & shift & goto :parse
    if "%~1"=="--name"       set "proj_name=%~2"     & shift & shift & goto :parse

    if "%~1"=="-title"       set "proj_title=%~2"    & shift & shift & goto :parse
    if "%~1"=="--title"      set "proj_title=%~2"    & shift & shift & goto :parse

    if "%~1"=="-path"        set "proj_path=%~2"     & shift & shift & goto :parse
    if "%~1"=="--path"       set "proj_path=%~2"     & shift & shift & goto :parse

    if "%~1"=="-version"     set "proj_version=%~2"  & shift & shift & goto :parse
    if "%~1"=="--version"    set "proj_version=%~2"  & shift & shift & goto :parse

    if "%~1"=="-repo"        set "proj_repo=%~2"     & shift & shift & goto :parse
    if "%~1"=="--repo"       set "proj_repo=%~2"     & shift & shift & goto :parse

    if "%~1"=="-user"        set "user_name=%~2"     & shift & shift & goto :parse
    if "%~1"=="--user"       set "user_name=%~2"     & shift & shift & goto :parse

    if "%~1"=="-user_name"   set "friendly_name=%~2" & shift & shift & goto :parse
    if "%~1"=="--user_name"  set "friendly_name=%~2" & shift & shift & goto :parse

    if "%~1"=="-email"       set "user_email=%~2"    & shift & shift & goto :parse
    if "%~1"=="--email"      set "user_email=%~2"    & shift & shift & goto :parse

    if not defined proj_name set "proj_name=%~1"     & shift & goto :parse

    REM shift
    REM goto :parse
    echo UNKNOWN ARGUMENT: %~1
    endlocal
    goto :end

:main
    if not defined proj_name (
        echo Missing project name ^(arg #1^)..
        endlocal
        exit /B
    )

    :: Validate the required values (or set defaults).
    if not defined proj_title   set "proj_title=!proj_name!"
    if not defined proj_path    set "proj_path=!user_name!"
    if not defined proj_version set "proj_version=0.1"
    if not defined proj_repo    set "proj_repo=github.com"

    :: Ensure directories exist.
    if not exist "%CD%\!proj_name!"      mkdir "%CD%\!proj_name!"      >NUL 2>&1
    if not exist "%CD%\!proj_name!\bin"  mkdir "%CD%\!proj_name!\bin"  >NUL 2>&1
    if not exist "%CD%\!proj_name!\pkg"  mkdir "%CD%\!proj_name!\pkg"  >NUL 2>&1

    set "src_path=%CD%\!proj_name!\src\!proj_repo!\!proj_path!\!proj_name!"
    if not exist "!src_path!"       mkdir "!src_path!"       >NUL 2>&1
    if not exist "!src_path!\build" mkdir "!src_path!\build" >NUL 2>&1

    :: Create .name and .version files.
    if not exist "!src_path!\.name" echo.!proj_name!>"!src_path!\.name"
    if not exist "!src_path!\.version" echo.!proj_version!>"!src_path!\.version"

    :: Create the source files.
    call :WriteLaunchJson
    call :WriteSettingsJson
    call :WriteBuildGo
    call :WriteMainGo

    :: Build project.
    cd "!src_path!"
    call gobuild.bat

    :: Permanently change to source directory.
    endlocal & set "__src_path=%src_path%"
    cd "%__src_path%"
    set "__src_path="

:end
    exit /B


:WriteSettingsJson
    set "settings_json=!src_path!\.vscode\settings.json"
    if not defined OptForceOverwrite if exist "!settings_json!" goto :eof

    set "full_go_path=%CD%\!proj_name!"
    set "full_go_path=!full_go_path:\=\\!"

    REM Create `.vscode\settings.json`

    echo.// Place your settings in this file to overwrite default and user settings.>"!settings_json!"
    echo.{>>"!settings_json!"
    echo.    "editor.tabSize": 4,>>"!settings_json!"
    echo.    "editor.insertSpaces": true,>>"!settings_json!"
    echo.    "editor.scrollBeyondLastLine": true,>>"!settings_json!"
    echo.    "editor.wrappingIndent": "same",>>"!settings_json!"
    echo.>>"!settings_json!"
    echo.    //-------- Go configuration -------->>"!settings_json!"
    echo.>>"!settings_json!"
    echo.    // Run 'go build'/'go test' on save.>>"!settings_json!"
    echo.    "go.buildOnSave": true,>>"!settings_json!"
    echo.>>"!settings_json!"
    echo.    // Flags to `go build` during build-on-save ^(e.g. ^['-ldflags="-s"'^]^)>>"!settings_json!"
    echo.    "go.buildFlags": ^[^],>>"!settings_json!"
    echo.>>"!settings_json!"
    echo.    // Run 'golint' on save.>>"!settings_json!"
    echo.    "go.lintOnSave": true,>>"!settings_json!"
    echo.>>"!settings_json!"
    echo.    // Flags to pass to `golint` ^(e.g. ^['-min_confidenc=.8'^]^)>>"!settings_json!"
    echo.    "go.lintFlags": ^[^],>>"!settings_json!"
    echo.>>"!settings_json!"
    echo.    // Run 'go tool vet' on save.>>"!settings_json!"
    echo.    "go.vetOnSave": true,>>"!settings_json!"
    echo.>>"!settings_json!"
    echo.    // Flags to pass to `go tool vet` ^(e.g. ^['-all', '-shadow'^]^)>>"!settings_json!"
    echo.    "go.vetFlags": ^[^],>>"!settings_json!"
    echo.>>"!settings_json!"
    echo.    // Pick 'gofmt', 'goimports' or 'goreturns' to run on format.>>"!settings_json!"
    echo.    "go.formatTool": "goreturns",>>"!settings_json!"
    echo.>>"!settings_json!"
    echo.    // Specifies the GOPATH to use when no environment variable is set.>>"!settings_json!"
    echo.	"go.gopath": "!full_go_path!",>>"!settings_json!"
    echo.>>"!settings_json!"
    echo.    // Specifies the GOROOT to use when no environment variable is set.>>"!settings_json!"
    echo.    // "go.goroot": "C:\\Go",>>"!settings_json!"
    echo.>>"!settings_json!"
    echo.    // ^[EXPERIMENTAL^] Run formatting tool on save.>>"!settings_json!"
    echo.    "go.formatOnSave": false,>>"!settings_json!"
    echo.>>"!settings_json!"
    echo.    // Specifies the timeout for go test in ParseDuration format.>>"!settings_json!"
    echo.    "go.testTimeout": "30s">>"!settings_json!"
    echo.}>>"!settings_json!"

    goto :eof

:WriteLaunchJson
    set "launch_json=!src_path!\.vscode\launch.json"
    if not defined OptForceOverwrite if exist "!launch_json!" goto :eof

    REM Create `.vscode\launch.json`

    echo.{>"!launch_json!"
    echo.    "version": "0.2.0",>>"!launch_json!"
    echo.    "configurations": [>>"!launch_json!"
    echo.        {>>"!launch_json!"
    echo.            "name": "Launch",>>"!launch_json!"
    echo.            "type": "go",>>"!launch_json!"
    echo.            "request": "launch",>>"!launch_json!"
    echo.            "mode": "debug",>>"!launch_json!"
    echo.            "remotePath": "",>>"!launch_json!"
    echo.            "port": 2345,>>"!launch_json!"
    echo.            "host": "127.0.0.1",>>"!launch_json!"
    echo.            "program": "${fileDirname}",>>"!launch_json!"
    echo.            "env": {>>"!launch_json!"
    echo.                "GOPATH": "${workspaceRoot}/../../../..">>"!launch_json!"
    echo.            },>>"!launch_json!"
    echo.            "args": [],>>"!launch_json!"
    echo.            "showLog": true>>"!launch_json!"
    echo.        }>>"!launch_json!"
    echo.    ]>>"!launch_json!"
    echo.}>>"!launch_json!"

    goto :eof

:WriteBuildGo
    set "build_go=!src_path!\build\build.go"
    if not defined OptForceOverwrite if exist "!build_go!" goto :eof

    REM Create `build\build.go`

    echo.package build>"!build_go!"
    echo.>>"!build_go!"
    echo.// Do not change anything in this file,>>"!build_go!"
    echo.// as it is overwritten during each build.>>"!build_go!"
    echo.>>"!build_go!"
    echo.// Date represents the date and time the app was built.>>"!build_go!"
    echo.var Date = "%_buildDate%">>"!build_go!"
    echo.>>"!build_go!"
    echo.// ShortVersion is the major.minor version.>>"!build_go!"
    echo.var ShortVersion = "!_buildVersion!">>"!build_go!"
    echo.>>"!build_go!"
    echo.// FullVersion is the full version: `major.minor.date.time`.>>"!build_go!"
    echo.var FullVersion = "%_buildString%">>"!build_go!"
    echo.>>"!build_go!"

    goto :eof

:WriteMainGo
    set "main_go=!src_path!\main.go"
    if not defined OptForceOverwrite if exist "!main_go!" goto :eof

    REM Create `main.go`
    set "CUR_YEAR=%DATE%"
    set "CUR_YEAR=!CUR_YEAR:~10,4!"

    echo.// Copyright ^(C^) !CUR_YEAR! !friendly_name!>"!main_go!"
    echo.// Author: !friendly_name! ^<!user_email!^>>>"!main_go!"
    echo.>>"!main_go!"
    echo.package main>>"!main_go!"
    echo.>>"!main_go!"
    echo.import ^(>>"!main_go!"
    echo.	"flag">>"!main_go!"
    echo.	"fmt">>"!main_go!"
    echo.	"log">>"!main_go!"
    echo.	"os">>"!main_go!"
    echo.>>"!main_go!"
    echo.	"!proj_repo!/!proj_path!/!proj_name!/build">>"!main_go!"
    echo.^)>>"!main_go!"
    echo.>>"!main_go!"
    echo.var ^(>>"!main_go!"
    echo.	version     bool>>"!main_go!"
    echo.	versionFull bool>>"!main_go!"
    echo.	debug       bool>>"!main_go!"
    echo.^)>>"!main_go!"
    echo.>>"!main_go!"
    echo.func init^(^) {>>"!main_go!"
    echo.	flag.BoolVar^(^&version, "v", false, "display build version"^)>>"!main_go!"
    echo.	flag.BoolVar^(^&versionFull, "version", false, "display build build version and copyright info"^)>>"!main_go!"
    echo.	flag.BoolVar^(^&debug, "debug", false, "enable debug mode"^)>>"!main_go!"
    echo.	flag.Parse^(^)>>"!main_go!"
    echo.}>>"!main_go!"
    echo.>>"!main_go!"
    echo.func main^(^) {>>"!main_go!"
    echo.	// Error handling>>"!main_go!"
    echo.	defer func^(^) {>>"!main_go!"
    echo.		if r := recover^(^); r ^^!= nil {>>"!main_go!"
    echo.			log.Fatal^("main() recovered", r^)>>"!main_go!"
    echo.		}>>"!main_go!"
    echo.	}^(^)>>"!main_go!"
    echo.>>"!main_go!"
    echo.	if debug {>>"!main_go!"
    echo.		fmt.Println^("DEBUG MODE: ON"^)>>"!main_go!"
    echo.	}>>"!main_go!"
    echo.>>"!main_go!"
    echo.	if version {>>"!main_go!"
    echo.		fmt.Printf^("%%s\n", build.ShortVersion^)>>"!main_go!"
    echo.		os.Exit^(0^)>>"!main_go!"
    echo.	} else if versionFull {>>"!main_go!"
    echo.		fmt.Printf^("!proj_title! %%s\n", build.FullVersion^)>>"!main_go!"
    echo.		if build.Date^[0:4^] == "!CUR_YEAR!" {>>"!main_go!"
    echo.			fmt.Printf^("Copyright ^(C^) %%s !friendly_name!.\n", build.Date^[0:4^]^)>>"!main_go!"
    echo.		} else {>>"!main_go!"
    echo.			fmt.Printf^("Copyright ^(C^) !CUR_YEAR!-%%s !friendly_name!.\n", build.Date^[0:4^]^)>>"!main_go!"
    echo.		}>>"!main_go!"
    REM echo.		fmt.Println^(^)>>"!main_go!"
    REM echo.		fmt.Println^("=============================================================================="^)>>"!main_go!"
    echo.		os.Exit^(0^)>>"!main_go!"
    echo.	}>>"!main_go!"
    echo.>>"!main_go!"
    echo.	fmt.Println^("Hello, World"^)>>"!main_go!"
    echo.}>>"!main_go!"
    echo.>>"!main_go!"

    goto :eof


:ShowHelp
    echo goinit.bat
    echo Copyright (C) 2012-2017 Kody Brown.
    echo Released under the MIT License.
    echo.
    echo EXAMPLE USAGE:
    echo.
    echo    goinit.bat --name testproject
    echo               --title "Test Project"           *optional
    echo               --path github.com                *optional
    echo               --version 0.1                    *optional
    echo               --user_name "Unknown User"       *optional
    echo               --user unknown                   *optional
    echo               --email someone@unknown.com      *optional
    echo.
    echo   will create:
    echo.
    echo      .\testproject
    echo      +---bin
    echo      ^|   \---windows_amd64
    echo      ^|           testproject.exe
    echo      +---pkg
    echo      ^|   \---windows_amd64
    echo      ^|           ...
    echo      \---src
    echo          \---github.com
    echo              \---unknown
    echo                  \---testproject
    echo                      ^|   .name
    echo                      ^|   .version
    echo                      ^|   main.go
    echo                      +---.vscode
    echo                      ^|       launch.json
    echo                      ^|       settings.json
    echo                      \---build
    echo                              build.go
    goto :eof
