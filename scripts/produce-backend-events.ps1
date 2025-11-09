Param(
  [int]$Count = 100,
  [string]$Bootstrap = 'kafka:9092'
)

Write-Host "[PRODUCE] Enviando $Count eventos a 'backend.events' en $Bootstrap" -ForegroundColor Cyan

$endpoints = @('/api/payments','/api/transfers','/api/auth/token','/api/health')
$users = @('raul','diana','mario','sofia','system')

# Construir archivo JSON Lines en disco (host) para preservar comillas correctamente
$tmp = Join-Path $env:TEMP "backend_events.jsonl"
if (Test-Path $tmp) { Remove-Item $tmp -Force }

for($i=0; $i -lt $Count; $i++){
  $ep = $endpoints[(Get-Random -Minimum 0 -Maximum $endpoints.Length)]
  $lat = Get-Random -Minimum 15 -Maximum 250
  if ((Get-Random -Minimum 0 -Maximum 10) -gt 1) { $status = 200 } else { $status = 500 }
  $user = $users[(Get-Random -Minimum 0 -Maximum $users.Length)]
  $amount = Get-Random -Minimum 50 -Maximum 20000
  $ts = (Get-Date).ToString('o')
  $json = @{ '@timestamp'=$ts; status_code=$status; amount=$amount; latency_ms=$lat; endpoint=$ep; user_id=$user } | ConvertTo-Json -Compress
  Add-Content -LiteralPath $tmp -Value $json
  if (($i+1) % 10 -eq 0) { Write-Progress -Activity "Generando eventos" -Status "$($i+1)/$Count" -PercentComplete ([int](($i+1)/$Count*100)) }
}

# Copiar al contenedor y producir
docker cp $tmp kafka:/tmp/backend_events.txt | Out-Null
docker exec kafka bash -lc "kafka-console-producer --bootstrap-server $Bootstrap --topic backend.events < /tmp/backend_events.txt" | Out-Null

Write-Host "[DONE] $Count eventos publicados." -ForegroundColor Green