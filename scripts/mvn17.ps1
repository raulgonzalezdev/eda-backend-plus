Param()

# Wrapper para ejecutar Maven con JDK 17 en PowerShell

function Get-Jdk17Home {
  if (Test-Path 'C:\Program Files\Java\jdk-17') { return 'C:\Program Files\Java\jdk-17' }
  if (Test-Path 'C:\Program Files\Eclipse Adoptium\jdk-17') { return 'C:\Program Files\Eclipse Adoptium\jdk-17' }
  if (Test-Path "$env:USERPROFILE\scoop\apps\temurin17-jdk\current") { return "$env:USERPROFILE\scoop\apps\temurin17-jdk\current" }
  throw 'No encuentro JDK 17 instalado. Ajuste la ruta en este script.'
}

try {
  $jdkHome = Get-Jdk17Home
} catch {
  Write-Error $_.Exception.Message
  exit 1
}

$env:JAVA_HOME = $jdkHome
$env:Path = (Join-Path $jdkHome 'bin') + ';' + $env:Path

# Neutraliza variable de entorno que el IDE pueda inyectar
Remove-Item Env:debugCommand -ErrorAction SilentlyContinue

if (Get-Command mvn -ErrorAction SilentlyContinue) {
  & mvn @args
} elseif (Get-Command mvn.cmd -ErrorAction SilentlyContinue) {
  & mvn.cmd @args
} else {
  Write-Error 'Maven no encontrado en PATH. Instálelo o añádalo al PATH.'
  exit 1
}