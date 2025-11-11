# Script de pruebas para Patroni + etcd cluster
# Autor: EDA Backend Team
# Fecha: $(Get-Date)

# === Cargar variables desde .env y .env.local ===
function Load-EnvFile {
    param([string]$Path)
    $vars = @{}
    if (Test-Path $Path) {
        Get-Content -LiteralPath $Path | ForEach-Object {
            $line = $_.Trim()
            if ($line -and -not $line.StartsWith('#')) {
                $idx = $line.IndexOf('=')
                if ($idx -gt 0) {
                    $key = $line.Substring(0, $idx).Trim()
                    $val = $line.Substring($idx + 1).Trim().Trim('"')
                    $vars[$key] = $val
                }
            }
        }
    }
    return $vars
}

$Root = Split-Path $PSScriptRoot -Parent
$envMain = Load-EnvFile (Join-Path $Root '.env')
$envLocal = Load-EnvFile (Join-Path $Root '.env.local')

# Merge: .env primero, .env.local sobrescribe
$envMap = $envMain.Clone()
foreach ($k in $envLocal.Keys) { $envMap[$k] = $envLocal[$k] }

# Variables de BD
$DB_NAME = $envMap['DB_NAME']; if (-not $DB_NAME) { $DB_NAME = 'sasdatqbox' }
$DB_USER = $envMap['DB_USER']; if (-not $DB_USER) { $DB_USER = 'sas_user' }
$DB_PASSWORD = $envMap['DB_PASSWORD']; if (-not $DB_PASSWORD) { $DB_PASSWORD = $envMap['POSTGRES_PASSWORD'] }
$DB_WRITE_HOST = $envMap['DB_WRITE_HOST']; if (-not $DB_WRITE_HOST) { $DB_WRITE_HOST = 'haproxy' }
$DB_WRITE_PORT = $envMap['DB_WRITE_PORT']; if (-not $DB_WRITE_PORT) { $DB_WRITE_PORT = 5000 }
$DB_READ_HOST = $envMap['DB_READ_HOST']; if (-not $DB_READ_HOST) { $DB_READ_HOST = 'haproxy' }
$DB_READ_PORT = $envMap['DB_READ_PORT']; if (-not $DB_READ_PORT) { $DB_READ_PORT = 5001 }

Write-Host "Iniciando pruebas del cluster Patroni + etcd..." -ForegroundColor Green

# Función para verificar estado de servicios
function Test-ServiceHealth {
    param($ServiceName, $Url, $ExpectedStatus = 200)
    
    try {
        $response = Invoke-WebRequest -Uri $Url -Method GET -TimeoutSec 10
        if ($response.StatusCode -eq $ExpectedStatus) {
            Write-Host ("OK " + $ServiceName + " (Status: " + $response.StatusCode + ")") -ForegroundColor Green
            return $true
        } else {
            Write-Host ("WARN " + $ServiceName + " (Unexpected status " + $response.StatusCode + ")") -ForegroundColor Yellow
            return $false
        }
    } catch {
        Write-Host ("ERROR " + $ServiceName + " - " + $_.Exception.Message) -ForegroundColor Red
        return $false
    }
}

# Función para probar conexión a base de datos
function Test-DatabaseConnection {
    param($DbHost, $DbPort, $DbName, $DbUser, $DbPassword, $Name)
    
    try {
        Write-Host ("Probando conexion a " + $Name + " (" + $DbHost + ":" + $DbPort + ")...")
        
        # Usar docker exec con PGPASSWORD para autenticar sin prompt
        $result = docker exec -e PGPASSWORD=$DbPassword patroni-master psql -h $DbHost -p $DbPort -U $DbUser -d $DbName -t -A -c "SELECT current_user, inet_server_addr(), inet_server_port(), pg_is_in_recovery();" 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ $Name: Conexión exitosa -> $result" -ForegroundColor Green
            return $true
        } else {
            Write-Host "❌ $Name: Error de conexión -> $result" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "❌ $Name: ERROR - $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

Write-Host "`n1) Verificando estado de etcd cluster..." -ForegroundColor Cyan
$etcdHealthy = $true
$etcdHealthy = $etcdHealthy -and (Test-ServiceHealth "etcd1" "http://localhost:2379/health")

Write-Host "`n2) Verificando estado de Patroni nodes..." -ForegroundColor Cyan
$patroniHealthy = $true
$patroniHealthy = $patroniHealthy -and (Test-ServiceHealth "Patroni Master" "http://localhost:8008/")
$patroniHealthy = $patroniHealthy -and (Test-ServiceHealth "Patroni Replica1" "http://localhost:8009/")
$patroniHealthy = $patroniHealthy -and (Test-ServiceHealth "Patroni Replica2" "http://localhost:8010/")

Write-Host "`n3) Verificando HAProxy..." -ForegroundColor Cyan
$haproxyHealthy = Test-ServiceHealth "HAProxy Stats" "http://localhost:7000/"

Write-Host "`n4) Verificando cluster status..." -ForegroundColor Cyan
try {
    Write-Host "Estado del cluster Patroni:"
    docker exec patroni-master patronictl -c /etc/patroni/patroni.yml list
} catch {
    Write-Host ("Error obteniendo estado del cluster: " + $_.Exception.Message) -ForegroundColor Red
}

Write-Host "`n5) Probando conexiones a base de datos..." -ForegroundColor Cyan
$dbHealthy = $true
# Probar conexión al Master (escritura) vía HAProxy dentro de la red docker
Write-Host ("Probando Master (puerto " + $DB_WRITE_PORT + " via HAProxy)...")
$dbHealthy = $dbHealthy -and (Test-DatabaseConnection $DB_WRITE_HOST $DB_WRITE_PORT $DB_NAME $DB_USER $DB_PASSWORD "Master via HAProxy")

# Probar conexión a Replicas (lectura)
Write-Host ("Probando Replicas (puerto " + $DB_READ_PORT + " via HAProxy)...")
$dbHealthy = $dbHealthy -and (Test-DatabaseConnection $DB_READ_HOST $DB_READ_PORT $DB_NAME $DB_USER $DB_PASSWORD "Replicas via HAProxy")

Write-Host "`n6) Probando aplicación EDA Backend (puerto fijo 8081)..." -ForegroundColor Cyan
$appsHealthy = $true
$appsHealthy = $appsHealthy -and (Test-ServiceHealth "APP Patroni" "http://localhost:8081/actuator/health")

Write-Host "`n7) Probando generación de tokens..." -ForegroundColor Cyan
try {
    $tokenResponse = Invoke-RestMethod -Uri "http://localhost:8081/api/auth/login" -Method POST -ContentType "application/json" -Body '{"username": "patroni_test_user", "password": "password123"}'
    Write-Host ("Token generado exitosamente: " + $tokenResponse.token.Substring(0,20) + "...") -ForegroundColor Green
} catch {
    Write-Host ("Error generando token: " + $_.Exception.Message) -ForegroundColor Red
}

# Resumen final
Write-Host "`nRESUMEN DE PRUEBAS:" -ForegroundColor Magenta
Write-Host "================================" -ForegroundColor Magenta
Write-Host "etcd Cluster: $(if($etcdHealthy){'OK'}else{'FAIL'})" -ForegroundColor $(if($etcdHealthy){'Green'}else{'Red'})
Write-Host "Patroni Nodes: $(if($patroniHealthy){'OK'}else{'FAIL'})" -ForegroundColor $(if($patroniHealthy){'Green'}else{'Red'})
Write-Host "HAProxy: $(if($haproxyHealthy){'OK'}else{'FAIL'})" -ForegroundColor $(if($haproxyHealthy){'Green'}else{'Red'})
Write-Host "Database Connections: $(if($dbHealthy){'OK'}else{'FAIL'})" -ForegroundColor $(if($dbHealthy){'Green'}else{'Red'})
Write-Host "EDA Applications: $(if($appsHealthy){'OK'}else{'FAIL'})" -ForegroundColor $(if($appsHealthy){'Green'}else{'Red'})

$overallHealth = $etcdHealthy -and $patroniHealthy -and $haproxyHealthy -and $dbHealthy -and $appsHealthy

if ($overallHealth) {
    Write-Host "`nCLUSTER PATRONI FUNCIONANDO CORRECTAMENTE!" -ForegroundColor Green
    Write-Host "Accesos disponibles:" -ForegroundColor Cyan
    Write-Host ("   • Master DB (escritura): " + $DB_WRITE_HOST + ":" + $DB_WRITE_PORT) -ForegroundColor White
    Write-Host ("   • Replicas DB (lectura): " + $DB_READ_HOST + ":" + $DB_READ_PORT) -ForegroundColor White
    Write-Host "   • HAProxy Stats: http://localhost:7000" -ForegroundColor White
    Write-Host "   • APP: http://localhost:8081" -ForegroundColor White
} else {
    Write-Host "`nALGUNOS SERVICIOS PRESENTAN PROBLEMAS" -ForegroundColor Yellow
    Write-Host "Revisa los logs de los servicios que fallaron." -ForegroundColor Yellow
}

Write-Host "`n📋 Para monitorear el cluster en tiempo real:" -ForegroundColor Cyan
Write-Host "   docker exec patroni-master patronictl -c /etc/patroni/patroni.yml list" -ForegroundColor White
Write-Host "   docker logs patroni-master -f" -ForegroundColor White