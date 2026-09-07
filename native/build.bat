@echo off
rem Construit la GDExtension, puis **pose son manifeste**.
rem
rem Le manifeste n'est pose qu'a la fin, et c'est ce qui rend le depot silencieux
rem sans chaine de compilation : Godot lit tout `.gdextension` qu'il trouve, et
rem un manifeste sans bibliotheque fait une erreur a chaque demarrage, pour tout
rem le monde. Tant que la bibliotheque n'existe pas, le manifeste non plus.
call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" >nul 2>&1
cd /d "%~dp0"
set CIBLE=%1
if "%CIBLE%"=="" set CIBLE=template_release
scons target=%CIBLE% platform=windows precision=double custom_api_file=api/extension_api.json -j8 < nul
if errorlevel 1 (
    echo.
    echo La construction a echoue : le manifeste n'est pas pose.
    exit /b 1
)
copy /y zentarys.gdextension.in zentarys.gdextension >nul
echo.
echo Manifeste pose. Relancer une fois avec --import pour que Godot le voie.
