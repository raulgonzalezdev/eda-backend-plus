param(
  [switch]$SkipTests
)

# Asegura Java 17 y Maven en la sesión actual
& "$PSScriptRoot\set-java17.ps1" | Out-Host

# Construye argumentos de Maven
$mvnArgs = @("spring-boot:run", '-D"spring-boot.run.profiles"=local')
if ($SkipTests) {
  $mvnArgs += '-DskipTests'
}

Write-Host "Iniciando aplicación con perfil 'local'..." -ForegroundColor Cyan
Write-Host "Comando: mvn $($mvnArgs -join ' ')" -ForegroundColor DarkGray

# Ejecuta Maven
& mvn @mvnArgs