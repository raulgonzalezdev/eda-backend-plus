# Script de pruebas para Patroni + etcd cluster
# Autor: EDA Backend Team
# Fecha: $(Get-Date)

Write-Host "🚀 Iniciando pruebas del cluster Patroni + etcd..." -ForegroundColor Green

# Función para verificar estado de servicios
function Test-ServiceHealth {
    param($ServiceName, $Url, $ExpectedStatus = 200)
    
    try {
        $response = Invoke-WebRequest -Uri $Url -Method GET -TimeoutSec 10
        if ($response.StatusCode -eq $ExpectedStatus) {
            Write-Host "✅ $ServiceName: OK (Status: $($response.StatusCode))" -ForegroundColor Green
            return $true
        } else {
            Write-Host "⚠️ $ServiceName: Unexpected status $($response.StatusCode)" -ForegroundColor Yellow
            return $false
        }
    } catch {
        Write-Host "❌ $ServiceName: ERROR - $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Función para probar conexión a base de datos
function Test-DatabaseConnection {
    param($Host, $Port, $Database, $Username, $Password, $Name)
    
    try {
        $connectionString = "Host=$Host;Port=$Port;Database=$Database;Username=$Username;Password=$Password;Timeout=10;"
        # Simulamos la conexión (en un entorno real usarías Npgsql)
        Write-Host "🔍 Probando conexión a $Name ($Host:$Port)..."
        
        # Usar docker exec para probar la conexión
        $result = docker exec patroni-master psql -h $Host -p $Port -U $Username -d $Database -c "SELECT 1;" 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ $Name: Conexión exitosa" -ForegroundColor Green
            return $true
        } else {
            Write-Host "❌ $Name: Error de conexión" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "❌ $Name: ERROR - $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

Write-Host "`n📊 1. Verificando estado de etcd cluster..." -ForegroundColor Cyan
$etcdHealthy = $true
$etcdHealthy = $etcdHealthy -and (Test-ServiceHealth "etcd1" "http://localhost:2379/health")

Write-Host "`n📊 2. Verificando estado de Patroni nodes..." -ForegroundColor Cyan
$patroniHealthy = $true
$patroniHealthy = $patroniHealthy -and (Test-ServiceHealth "Patroni Master" "http://localhost:8008/")
$patroniHealthy = $patroniHealthy -and (Test-ServiceHealth "Patroni Replica1" "http://localhost:8009/")
$patroniHealthy = $patroniHealthy -and (Test-ServiceHealth "Patroni Replica2" "http://localhost:8010/")

Write-Host "`n📊 3. Verificando HAProxy..." -ForegroundColor Cyan
$haproxyHealthy = Test-ServiceHealth "HAProxy Stats" "http://localhost:7000/"

Write-Host "`n📊 4. Verificando cluster status..." -ForegroundColor Cyan
try {
    Write-Host "🔍 Estado del cluster Patroni:"
    docker exec patroni-master patronictl -c /etc/patroni/patroni.yml list
} catch {
    Write-Host "❌ Error obteniendo estado del cluster: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n📊 5. Probando conexiones a base de datos..." -ForegroundColor Cyan
$dbHealthy = $true
# Probar conexión al Master (escritura)
Write-Host "🔍 Probando Master (puerto 5000 via HAProxy)..."
$dbHealthy = $dbHealthy -and (Test-DatabaseConnection "localhost" "5000" "sasdatqbox" "sas_user" "ML!gsx90l02" "Master via HAProxy")

# Probar conexión a Replicas (lectura)
Write-Host "🔍 Probando Replicas (puerto 5001 via HAProxy)..."
$dbHealthy = $dbHealthy -and (Test-DatabaseConnection "localhost" "5001" "sasdatqbox" "sas_user" "ML!gsx90l02" "Replicas via HAProxy")

Write-Host "`n📊 6. Probando aplicaciones EDA Backend..." -ForegroundColor Cyan
$appsHealthy = $true
$appsHealthy = $appsHealthy -and (Test-ServiceHealth "APP1 Patroni" "http://localhost:8080/actuator/health")
$appsHealthy = $appsHealthy -and (Test-ServiceHealth "APP2 Patroni" "http://localhost:8081/actuator/health")
$appsHealthy = $appsHealthy -and (Test-ServiceHealth "APP3 Patroni" "http://localhost:8082/actuator/health")

Write-Host "`n📊 7. Probando generación de tokens..." -ForegroundColor Cyan
try {
    $tokenResponse = Invoke-RestMethod -Uri "http://localhost:8080/api/auth/login" -Method POST -ContentType "application/json" -Body '{"username": "patroni_test_user", "password": "password123"}'
    Write-Host "✅ Token generado exitosamente: $($tokenResponse.token.Substring(0,20))..." -ForegroundColor Green
} catch {
    Write-Host "❌ Error generando token: $($_.Exception.Message)" -ForegroundColor Red
}

# Resumen final
Write-Host "`n🎯 RESUMEN DE PRUEBAS:" -ForegroundColor Magenta
Write-Host "================================" -ForegroundColor Magenta
Write-Host "etcd Cluster: $(if($etcdHealthy){'✅ OK'}else{'❌ FAIL'})" -ForegroundColor $(if($etcdHealthy){'Green'}else{'Red'})
Write-Host "Patroni Nodes: $(if($patroniHealthy){'✅ OK'}else{'❌ FAIL'})" -ForegroundColor $(if($patroniHealthy){'Green'}else{'Red'})
Write-Host "HAProxy: $(if($haproxyHealthy){'✅ OK'}else{'❌ FAIL'})" -ForegroundColor $(if($haproxyHealthy){'Green'}else{'Red'})
Write-Host "Database Connections: $(if($dbHealthy){'✅ OK'}else{'❌ FAIL'})" -ForegroundColor $(if($dbHealthy){'Green'}else{'Red'})
Write-Host "EDA Applications: $(if($appsHealthy){'✅ OK'}else{'❌ FAIL'})" -ForegroundColor $(if($appsHealthy){'Green'}else{'Red'})

$overallHealth = $etcdHealthy -and $patroniHealthy -and $haproxyHealthy -and $dbHealthy -and $appsHealthy

if ($overallHealth) {
    Write-Host "`n🎉 ¡CLUSTER PATRONI FUNCIONANDO CORRECTAMENTE!" -ForegroundColor Green
    Write-Host "🔗 Accesos disponibles:" -ForegroundColor Cyan
    Write-Host "   • Master DB (escritura): localhost:5000" -ForegroundColor White
    Write-Host "   • Replicas DB (lectura): localhost:5001" -ForegroundColor White
    Write-Host "   • HAProxy Stats: http://localhost:7000" -ForegroundColor White
    Write-Host "   • APP1: http://localhost:8080" -ForegroundColor White
    Write-Host "   • APP2: http://localhost:8081" -ForegroundColor White
    Write-Host "   • APP3: http://localhost:8082" -ForegroundColor White
} else {
    Write-Host "`n⚠️ ALGUNOS SERVICIOS PRESENTAN PROBLEMAS" -ForegroundColor Yellow
    Write-Host "Revisa los logs de los servicios que fallaron." -ForegroundColor Yellow
}

Write-Host "`n📋 Para monitorear el cluster en tiempo real:" -ForegroundColor Cyan
Write-Host "   docker exec patroni-master patronictl -c /etc/patroni/patroni.yml list" -ForegroundColor White
Write-Host "   docker logs patroni-master -f" -ForegroundColor White