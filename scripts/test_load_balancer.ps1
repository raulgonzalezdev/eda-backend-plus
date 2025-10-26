# Script para probar el balanceador de carga NGINX
# Autor: Sistema EDA Backend Plus

param(
    [string]$LoadBalancerUrl = "http://localhost:8085",
    [int]$TestRequests = 20,
    [int]$DelayBetweenRequests = 100
)

# Función para hacer peticiones HTTP
function Invoke-HttpRequest {
    param(
        [string]$Url,
        [int]$TimeoutSeconds = 10
    )
    
    try {
        $response = Invoke-WebRequest -Uri $Url -TimeoutSec $TimeoutSeconds -UseBasicParsing
        return @{
            Success = $true
            StatusCode = $response.StatusCode
            Content = $response.Content
            Server = $response.Headers['Server']
        }
    }
    catch {
        return @{
            Success = $false
            Error = $_.Exception.Message
            StatusCode = $null
        }
    }
}

# Función para obtener el estado de los contenedores
function Get-ContainerStatus {
    param([string]$ContainerName)
    
    try {
        $status = docker ps --filter "name=$ContainerName" --format "{{.Status}}"
        if ($status) {
            if ($status -like "*Up*") {
                Write-Host "✓ ${ContainerName}: RUNNING" -ForegroundColor Green
                return $true
            } else {
                Write-Host "✗ ${ContainerName}: NOT RUNNING" -ForegroundColor Red
                return $false
            }
        } else {
            Write-Host "✗ ${ContainerName}: NOT FOUND" -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "✗ ${ContainerName}: ERROR - $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Función para probar el health check
function Test-HealthCheck {
    param([string]$BaseUrl)
    
    Write-Host "`n=== PROBANDO HEALTH CHECKS ===" -ForegroundColor Cyan
    
    $healthUrls = @(
        "$BaseUrl/api/health",
        "$BaseUrl/health"
    )
    
    foreach ($url in $healthUrls) {
        Write-Host "Probando: $url" -ForegroundColor Yellow
        $result = Invoke-HttpRequest -Url $url
        
        if ($result.Success) {
            Write-Host "✓ Health check exitoso - Status: $($result.StatusCode)" -ForegroundColor Green
            Write-Host "  Respuesta: $($result.Content)" -ForegroundColor Gray
        } else {
            Write-Host "✗ Health check falló - Error: $($result.Error)" -ForegroundColor Red
        }
    }
}

# Función para probar la distribución de carga
function Test-LoadDistribution {
    param(
        [string]$BaseUrl,
        [int]$RequestCount
    )
    
    Write-Host "`n=== PROBANDO DISTRIBUCIÓN DE CARGA ===" -ForegroundColor Cyan
    Write-Host "Enviando $RequestCount peticiones a $BaseUrl/api/health" -ForegroundColor Yellow
    
    $serverCounts = @{}
    $successCount = 0
    $failCount = 0
    
    for ($i = 1; $i -le $RequestCount; $i++) {
        Write-Progress -Activity "Enviando peticiones" -Status "Petición $i de $RequestCount" -PercentComplete (($i / $RequestCount) * 100)
        
        $result = Invoke-HttpRequest -Url "$BaseUrl/api/health"
        
        if ($result.Success) {
            $successCount++
            $serverInfo = "app-instance"
            if ($serverCounts.ContainsKey($serverInfo)) {
                $serverCounts[$serverInfo]++
            } else {
                $serverCounts[$serverInfo] = 1
            }
        } else {
            $failCount++
        }
        
        Start-Sleep -Milliseconds $DelayBetweenRequests
    }
    
    Write-Progress -Activity "Enviando peticiones" -Completed
    
    Write-Host "`n--- RESULTADOS DE DISTRIBUCIÓN ---" -ForegroundColor Green
    Write-Host "Peticiones exitosas: $successCount" -ForegroundColor Green
    Write-Host "Peticiones fallidas: $failCount" -ForegroundColor Red
    
    if ($serverCounts.Count -gt 0) {
        Write-Host "`nDistribución por servidor:" -ForegroundColor Yellow
        foreach ($server in $serverCounts.Keys) {
            $count = $serverCounts[$server]
            $percentage = [math]::Round(($count / $successCount) * 100, 2)
            Write-Host "  ${server}: $count requests (${percentage}%)" -ForegroundColor White
        }
    }
}

# Función para probar failover
function Test-Failover {
    param([string]$BaseUrl)
    
    Write-Host "`n=== PROBANDO FAILOVER ===" -ForegroundColor Cyan
    
    # Verificar estado inicial
    Write-Host "Estado inicial de los contenedores:" -ForegroundColor Yellow
    $containers = @("eda-backend-app1", "eda-backend-app2", "eda-backend-app3")
    foreach ($container in $containers) {
        Get-ContainerStatus -ContainerName $container
    }
    
    # Probar conectividad inicial
    Write-Host "`nProbando conectividad inicial..." -ForegroundColor Yellow
    $result = Invoke-HttpRequest -Url "$BaseUrl/api/health"
    if ($result.Success) {
        Write-Host "✓ Conectividad inicial OK" -ForegroundColor Green
    } else {
        Write-Host "✗ Conectividad inicial falló" -ForegroundColor Red
        return
    }
    
    # Simular fallo de una instancia
    Write-Host "`nSimulando fallo de app1..." -ForegroundColor Yellow
    try {
        docker stop eda-backend-app1
        Write-Host "✓ app1 detenida" -ForegroundColor Yellow
        
        # Esperar un momento para que NGINX detecte el fallo
        Start-Sleep -Seconds 5
        
        # Probar conectividad después del fallo
        Write-Host "Probando conectividad después del fallo..." -ForegroundColor Yellow
        $result = Invoke-HttpRequest -Url "$BaseUrl/api/health"
        if ($result.Success) {
            Write-Host "✓ Failover exitoso - El sistema sigue funcionando" -ForegroundColor Green
        } else {
            Write-Host "✗ Failover falló - El sistema no responde" -ForegroundColor Red
        }
        
        # Restaurar la instancia
        Write-Host "`nRestaurando app1..." -ForegroundColor Yellow
        docker start eda-backend-app1
        Write-Host "✓ app1 restaurada" -ForegroundColor Green
        
        # Esperar a que se recupere
        Start-Sleep -Seconds 10
        
        # Verificar recuperación
        Write-Host "Verificando recuperación..." -ForegroundColor Yellow
        $result = Invoke-HttpRequest -Url "$BaseUrl/api/health"
        if ($result.Success) {
            Write-Host "✓ Recuperación exitosa" -ForegroundColor Green
        } else {
            Write-Host "✗ Recuperación falló" -ForegroundColor Red
        }
        
    } catch {
        Write-Host "✗ Error durante la prueba de failover: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Función principal
function Start-LoadBalancerTest {
    Write-Host "=== PRUEBAS DEL BALANCEADOR DE CARGA NGINX ===" -ForegroundColor Magenta
    Write-Host "URL del balanceador: $LoadBalancerUrl" -ForegroundColor White
    Write-Host "Número de peticiones de prueba: $TestRequests" -ForegroundColor White
    Write-Host "Retraso entre peticiones: $DelayBetweenRequests ms" -ForegroundColor White
    
    # Verificar estado de contenedores
    Write-Host "`n=== VERIFICANDO ESTADO DE CONTENEDORES ===" -ForegroundColor Cyan
    $containers = @("nginx-load-balancer", "eda-backend-app1", "eda-backend-app2", "eda-backend-app3")
    $allRunning = $true
    
    foreach ($container in $containers) {
        $status = Get-ContainerStatus -ContainerName $container
        if (-not $status) {
            $allRunning = $false
        }
    }
    
    if (-not $allRunning) {
        Write-Host "`n⚠️  Algunos contenedores no están ejecutándose. Continuando con las pruebas..." -ForegroundColor Yellow
    }
    
    # Ejecutar pruebas
    Test-HealthCheck -BaseUrl $LoadBalancerUrl
    Test-LoadDistribution -BaseUrl $LoadBalancerUrl -RequestCount $TestRequests
    Test-Failover -BaseUrl $LoadBalancerUrl
    
    Write-Host "`n=== PRUEBAS COMPLETADAS ===" -ForegroundColor Magenta
    Write-Host "Revisa los resultados anteriores para verificar el funcionamiento del balanceador." -ForegroundColor White
}

# Ejecutar las pruebas
Start-LoadBalancerTest