@echo off
setlocal

rem Wrapper para ejecutar Maven con JDK 17 independientemente del entorno del IDE

set "JAVA_HOME=C:\Program Files\Java\jdk-17"
if not exist "%JAVA_HOME%\bin\java.exe" (
  if exist "C:\Program Files\Eclipse Adoptium\jdk-17\bin\java.exe" (
    set "JAVA_HOME=C:\Program Files\Eclipse Adoptium\jdk-17"
  ) else if exist "%USERPROFILE%\scoop\apps\temurin17-jdk\current\bin\java.exe" (
    set "JAVA_HOME=%USERPROFILE%\scoop\apps\temurin17-jdk\current"
  )
)

if not exist "%JAVA_HOME%\bin\java.exe" (
  echo No se encontro java.exe en JDK 17. Ajuste JAVA_HOME en este script.
  exit /b 1
)

set "PATH=%JAVA_HOME%\bin;%PATH%"

rem Usar el mvn del PATH (Scoop u otra instalacion)
where mvn >nul 2>nul
if errorlevel 1 (
  echo Maven no encontrado en PATH. Agregue Maven al PATH o instale Maven.
  exit /b 1
)

call mvn %*

endlocal