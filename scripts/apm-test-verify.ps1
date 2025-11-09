Param(
  [int]$Count = 20,
  [string]$BaseUrl = 'http://localhost:8080',
  [string]$ElasticUrl = 'http://localhost:9200',
  [string]$KibanaUrl  = 'http://localhost:5601',
  [string]$ElasticUser = 'elastic',
  [string]$ElasticPassword = 'changeme'
)

Write-Host "[APM Test] Iniciando pruebas y verificación" -ForegroundColor Cyan

function New-EsHeaders([string]$user, [string]$pass) {
  $b64 = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$user:$pass"))
  return @{ Authorization = "Basic $b64"; 'Content-Type'='application/json' }
}

function Invoke-Es([string]$uri, [string]$method = 'GET') {
  $headers = New-EsHeaders -user $ElasticUser -pass $ElasticPassword
  return Invoke-WebRequest -Uri $uri -Method $method -Headers $headers -UseBasicParsing
}

function Kibana-Status {
  Write-Host "[Kibana] Consultando /api/status..." -ForegroundColor Yellow
  $headers = New-EsHeaders -user $ElasticUser -pass $ElasticPassword
  $resp = Invoke-WebRequest -Uri "$KibanaUrl/api/status" -Headers $headers -UseBasicParsing -Method GET
  Write-Host $resp.Content
}

function Generate-Traffic {
  Write-Host "[Traffic] Generando $Count pagos y $Count transferencias en $BaseUrl..." -ForegroundColor Yellow
  $scriptPath = Join-Path (Get-Location) "scripts/observability_smoke.ps1"
  if (Test-Path $scriptPath) {
    & pwsh $scriptPath -Count $Count -BaseUrl $BaseUrl
  } else {
    Write-Warning "No se encontró scripts/observability_smoke.ps1. Omite generación de tráfico."
  }
}

function Apm-Server-Logs {
  Write-Host "[APM] Últimos logs de apm-server (200 líneas)..." -ForegroundColor Yellow
  try {
    & docker compose logs --tail=200 apm-server
  } catch {
    Write-Warning "No se pudo leer logs de apm-server. ¿Está levantado docker compose?"
  }
}

function Verify-DataStreams {
  Write-Host "[ES] Data streams actuales..." -ForegroundColor Yellow
  $resp = Invoke-Es -uri "$ElasticUrl/_data_stream?pretty"
  Write-Host $resp.Content
}

function Verify-Indices {
  Write-Host "[ES] Índices APM (logs, metrics, traces)..." -ForegroundColor Yellow
  $logs  = Invoke-Es -uri "$ElasticUrl/_cat/indices/logs-apm*?v"
  $metrics = Invoke-Es -uri "$ElasticUrl/_cat/indices/metrics-apm*?v"
  $traces  = Invoke-Es -uri "$ElasticUrl/_cat/indices/traces-apm*?v"
  Write-Host "[logs-apm*]\n$($logs.Content)"
  Write-Host "[metrics-apm*]\n$($metrics.Content)"
  Write-Host "[traces-apm*]\n$($traces.Content)"
}

function Print-Useful-Urls {
  Write-Host "[URLs útiles]" -ForegroundColor Yellow
  Write-Host "Kibana APM Services: $KibanaUrl/app/apm/services?rangeFrom=now-30m&rangeTo=now"
  Write-Host "Kibana Discover: $KibanaUrl/app/discover#/?_a=(index:'traces-apm*')"
}

Write-Host "[Run] Paso 1: Kibana status" -ForegroundColor Cyan
Kibana-Status

Write-Host "[Run] Paso 2: generar tráfico" -ForegroundColor Cyan
Generate-Traffic

Write-Host "[Run] Paso 3: verificar logs de apm-server" -ForegroundColor Cyan
Apm-Server-Logs

Write-Host "[Run] Paso 4: verificar data streams e índices" -ForegroundColor Cyan
Verify-DataStreams
Verify-Indices

Write-Host "[Run] Paso 5: abrir URLs útiles (copiar/pegar)" -ForegroundColor Cyan
Print-Useful-Urls

Write-Host "[Done] Revisa que existan traces/metrics/logs y que apm-server responda 200 en /v1/*" -ForegroundColor Green