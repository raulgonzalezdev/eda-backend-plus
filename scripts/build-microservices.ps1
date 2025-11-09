Param(
  [switch]$SkipTests
)

Write-Host "[Build] Compilando microservicios (sin ejecutar contenedores)..." -ForegroundColor Cyan

$mvnArgs = "-DskipTests=$($SkipTests.IsPresent)"

function Build-Module($path) {
  Write-Host "[Build] $path" -ForegroundColor Yellow
  mvn -f $path/pom.xml $mvnArgs package | Out-Host
}

Build-Module "services/payments-service"
Build-Module "services/transfers-service"
Build-Module "services/alerts-service"
Build-Module "services/gateway-service"

Write-Host "[Build] Finalizado. JARs generados en target/ de cada servicio." -ForegroundColor Green
Write-Host "[Next] Para construir imágenes (opcional): docker compose -f docker-compose.microservices.yml build" -ForegroundColor DarkGreen