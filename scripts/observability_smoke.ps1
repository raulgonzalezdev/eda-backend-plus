Param(
  [int]$Count = 15,
  [int]$DelayMs = 300,
  [string]$BaseUrl = 'http://localhost:8080',
  [int]$AlertsTimeoutMs = 5000,
  [int]$DbWaitSeconds = 10
)

$ErrorActionPreference = 'Stop'
Write-Host "[OBS] Iniciando smoke de observabilidad contra $BaseUrl" -ForegroundColor Cyan

function Get-Token {
  param([string]$Sub = 'obs-user',[string]$Scope = 'USER')
  $uri = "$BaseUrl/auth/token?sub=$Sub&scope=$Scope"
  $t = (Invoke-WebRequest -Uri $uri -UseBasicParsing -TimeoutSec 10).Content
  return $t
}

function Call-Json {
  param([string]$Uri,[hashtable]$Headers,[object]$Body,[string]$Method='POST')
  $json = $Body | ConvertTo-Json -Depth 4
  return Invoke-WebRequest -Uri $Uri -Method $Method -Headers $Headers -Body $json -ContentType 'application/json' -UseBasicParsing -TimeoutSec 10
}

# 1) Health sin JWT
Write-Host "[OBS] Health (publico)" -ForegroundColor Yellow
Invoke-WebRequest -Uri "$BaseUrl/api/health" -UseBasicParsing -TimeoutSec 5 | Out-Null
Invoke-WebRequest -Uri "$BaseUrl/actuator/health" -UseBasicParsing -TimeoutSec 5 | Out-Null

# 2) Obtener JWT
Write-Host "[OBS] Obteniendo token JWT" -ForegroundColor Yellow
$token = Get-Token
$headers = @{ Authorization = "Bearer $token"; 'Content-Type' = 'application/json' }
Write-Host "[OBS] Token OK" -ForegroundColor Green

# 3) Ping DB (con JWT)
Write-Host "[OBS] DB ping" -ForegroundColor Yellow
try { Invoke-WebRequest -Uri "$BaseUrl/db/ping" -UseBasicParsing -Headers $headers -TimeoutSec 5 | Out-Null } catch { Write-Host "[OBS] Ping DB requiere JWT o está protegido" -ForegroundColor DarkYellow }

# 4) Generar tráfico: payments y transfers
Write-Host "[OBS] Generando $Count pagos y $Count transferencias" -ForegroundColor Yellow
for ($i=0; $i -lt $Count; $i++) {
  $paymentId = [guid]::NewGuid().ToString()
  $transferId = [guid]::NewGuid().ToString()
  Call-Json -Uri "$BaseUrl/events/payments" -Headers $headers -Body @{ id=$paymentId; amount=15000; type='payment'; currency='USD'; accountId='acc-obs' } | Out-Null
  Start-Sleep -Milliseconds $DelayMs
  Call-Json -Uri "$BaseUrl/events/transfers" -Headers $headers -Body @{ id=$transferId; amount=16000; type='transfer'; fromAccount='acc-a'; toAccount='acc-b' } | Out-Null
  Start-Sleep -Milliseconds $DelayMs
}
Write-Host "[OBS] Tráfico generado" -ForegroundColor Green

# 5) Consultar alertas (Kafka Streams + AlertsConsumer)
Write-Host "[OBS] Consultando alertas (Kafka) (timeoutMs=$AlertsTimeoutMs)" -ForegroundColor Yellow
$alerts = (Invoke-WebRequest -Uri "$BaseUrl/alerts?timeoutMs=$AlertsTimeoutMs" -UseBasicParsing -Headers $headers).Content
Write-Host "[OBS] alerts? => $alerts" -ForegroundColor Gray

Write-Host "[OBS] Esperando $DbWaitSeconds s antes de consultar alertas en DB" -ForegroundColor Yellow
Start-Sleep -Seconds $DbWaitSeconds
Write-Host "[OBS] Consultando alertas en DB" -ForegroundColor Yellow
$alertsDb = (Invoke-WebRequest -Uri "$BaseUrl/alerts-db" -UseBasicParsing -Headers $headers).Content
Write-Host "[OBS] alerts-db => $alertsDb" -ForegroundColor Gray

Write-Host "[OBS] Fin. Abre Kibana en http://localhost:5601/ y ve a APM > Services (servicio: eda-backend)." -ForegroundColor Cyan