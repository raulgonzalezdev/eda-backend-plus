# Script para probar el sistema de migraciones automáticas de Patroni
# Este script detiene el cluster, limpia los datos y lo reinicia para probar la inicialización automática

Write-Host "=== Probando Sistema de Migraciones Automáticas de Patroni ===" -ForegroundColor Green

# Función para mostrar estado
function Show-Status {
    param($Message)
    Write-Host ">>> $Message" -ForegroundColor Yellow
}

# Función para esperar
function Wait-Seconds {
    param($Seconds, $Message)
    Write-Host "Esperando $Seconds segundos - $Message..." -ForegroundColor Cyan
    Start-Sleep -Seconds $Seconds
}

try {
    Show-Status "Deteniendo cluster Patroni actual..."
    docker compose -f docker-compose-patroni.yml down -v
    
    Wait-Seconds 5 "Limpiando recursos"
    
    Show-Status "Reconstruyendo imágenes con nuevos scripts de migración..."
    docker compose -f docker-compose-patroni.yml build --no-cache
    
    Wait-Seconds 3 "Preparando inicio"
    
    Show-Status "Iniciando cluster Patroni con migraciones automáticas..."
    docker compose -f docker-compose-patroni.yml up -d
    
    Wait-Seconds 30 "Inicialización del cluster"
    
    Show-Status "Verificando estado del cluster..."
    $clusterStatus = Invoke-WebRequest -Uri "http://localhost:8008/cluster" -UseBasicParsing -TimeoutSec 10
    Write-Host "Estado del cluster: $($clusterStatus.StatusCode)" -ForegroundColor Green
    
    Wait-Seconds 10 "Estabilización de servicios"
    
    Show-Status "Verificando base de datos y tablas..."
    docker exec patroni-master psql -U sas_user -d sasdatqbox -c "\dt pos.*"
    
    Show-Status "Verificando datos de prueba..."
    docker exec patroni-master psql -U sas_user -d sasdatqbox -c "SELECT COUNT(*) as total_tables FROM information_schema.tables WHERE table_schema = 'pos';"
    
    Write-Host "=== Prueba de Migraciones Completada Exitosamente ===" -ForegroundColor Green
    
} catch {
    Write-Host "Error durante la prueba: $_" -ForegroundColor Red
    Write-Host "Revisando logs del contenedor..." -ForegroundColor Yellow
    docker logs patroni-master --tail 20
}

Write-Host "Presiona cualquier tecla para continuar..." -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")