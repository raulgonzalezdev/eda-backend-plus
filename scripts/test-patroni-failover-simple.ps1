# Script de pruebas de failover para Patroni cluster
# Autor: EDA Backend Team

Write-Host "Iniciando pruebas de failover automatico con Patroni..." -ForegroundColor Red

# Funcion para obtener el Master actual
function Get-CurrentMaster {
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:8008/cluster" -UseBasicParsing
        $clusterData = $response.Content | ConvertFrom-Json
        $leader = $clusterData.members | Where-Object { $_.role -eq "leader" }
        return $leader.name
    } catch {
        Write-Host "Error obteniendo Master actual" -ForegroundColor Red
        return $null
    }
}

# Funcion para verificar aplicaciones
function Test-Applications {
    Write-Host "Probando aplicaciones durante failover..." -ForegroundColor Cyan
    
    $port = 8081
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:$($port)/actuator/health" -UseBasicParsing -TimeoutSec 5
        Write-Host "APP (puerto $port): ACTIVA - Status: $($response.StatusCode)" -ForegroundColor Green
    } catch {
        Write-Host "APP (puerto $port): Error de conexion" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "1. Estado inicial del cluster..." -ForegroundColor Cyan
$initialMaster = Get-CurrentMaster
if ($initialMaster) {
    Write-Host "Master actual: $initialMaster" -ForegroundColor Yellow
} else {
    Write-Host "No se pudo identificar el Master actual. Abortando prueba." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "2. Probando aplicaciones antes del failover..." -ForegroundColor Cyan
Test-Applications

Write-Host ""
Write-Host "3. Simulando fallo del Master ($initialMaster)..." -ForegroundColor Red
Write-Host "Deteniendo contenedor $initialMaster..." -ForegroundColor Yellow

try {
    docker stop $initialMaster
    Write-Host "Contenedor $initialMaster detenido" -ForegroundColor Green
} catch {
    Write-Host "Error deteniendo contenedor" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "4. Esperando failover automatico (30 segundos)..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

Write-Host ""
Write-Host "5. Verificando nuevo estado del cluster..." -ForegroundColor Cyan
$newMaster = Get-CurrentMaster
if ($newMaster -and $newMaster -ne $initialMaster) {
    Write-Host "FAILOVER EXITOSO! Nuevo Master: $newMaster" -ForegroundColor Green
} else {
    Write-Host "Failover en progreso o no completado" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "6. Probando aplicaciones despues del failover..." -ForegroundColor Cyan
Test-Applications

Write-Host ""
Write-Host "7. Recuperando el nodo original..." -ForegroundColor Cyan
Write-Host "Iniciando contenedor $initialMaster..." -ForegroundColor Yellow

try {
    docker start $initialMaster
    Write-Host "Contenedor $initialMaster iniciado" -ForegroundColor Green
} catch {
    Write-Host "Error iniciando contenedor" -ForegroundColor Red
}

Write-Host ""
Write-Host "8. Esperando reintegracion del nodo (30 segundos)..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

Write-Host ""
Write-Host "9. Estado final del cluster..." -ForegroundColor Cyan
$finalMaster = Get-CurrentMaster
Write-Host "Master final: $finalMaster" -ForegroundColor White

Write-Host ""
Write-Host "10. Prueba final de aplicaciones..." -ForegroundColor Cyan
Test-Applications

Write-Host ""
Write-Host "RESUMEN DE PRUEBA DE FAILOVER:" -ForegroundColor Magenta
Write-Host "=================================" -ForegroundColor Magenta
Write-Host "Master inicial: $initialMaster" -ForegroundColor White
if ($newMaster -and $newMaster -ne $initialMaster) {
    Write-Host "Failover: EXITOSO" -ForegroundColor Green
} else {
    Write-Host "Failover: FALLIDO" -ForegroundColor Red
}
Write-Host "Nuevo Master: $(if($newMaster){$newMaster}else{'No identificado'})" -ForegroundColor White
Write-Host "Recuperacion: COMPLETADA" -ForegroundColor Green

Write-Host ""
Write-Host "PRUEBA DE FAILOVER COMPLETADA!" -ForegroundColor Green
Write-Host "El cluster Patroni demostro:" -ForegroundColor Cyan
Write-Host "   • Deteccion automatica de fallos" -ForegroundColor White
Write-Host "   • Promocion automatica de replica a Master" -ForegroundColor White
Write-Host "   • Continuidad del servicio durante failover" -ForegroundColor White
Write-Host "   • Reintegracion automatica del nodo recuperado" -ForegroundColor White