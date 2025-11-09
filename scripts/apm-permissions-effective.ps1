Param(
  [string]$ElasticUrl = 'http://localhost:9200',
  [string]$User = 'apm_writer',
  [string]$Password = 'changemeAPMWRITER',
  [string[]]$IndexPatterns = @('logs-apm*','metrics-apm*','traces-apm*'),
  [string[]]$Privileges = @('auto_configure','create_index','write','create_doc'),
  [switch]$ShowDataStreams,
  [string]$AdminUser = 'elastic',
  [string]$AdminPassword = 'changeme'
)

Write-Host "[APM] Verificación de privilegios efectivos para '$User'" -ForegroundColor Cyan

function New-Headers([string]$u,[string]$p){
  $b64 = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$u:$p"))
  return @{ Authorization = "Basic $b64"; 'Content-Type'='application/json' }
}

function Test-Privileges {
  param([string[]]$patterns,[string[]]$privs)
  $headers = New-Headers -u $User -p $Password
  $indexEntries = @()
  foreach($name in $patterns){
    $indexEntries += @{ names = @($name); privileges = $privs }
  }
  $payload = @{ index = $indexEntries } | ConvertTo-Json -Depth 5
  $resp = Invoke-WebRequest -Uri "$ElasticUrl/_security/user/_has_privileges" -Method POST -Headers $headers -Body $payload -UseBasicParsing
  $obj = $resp.Content | ConvertFrom-Json
  Write-Host "has_all_requested: $($obj.has_all_requested)" -ForegroundColor Yellow
  Write-Host "Detalle por índice/patrón:" -ForegroundColor Yellow
  foreach($entry in $obj.index){
    $n = $entry.names -join ','
    $allowed = $entry.allowed
    Write-Host ("  - {0} => allowed: {1}" -f $n, $allowed) -ForegroundColor (if($allowed){'Green'}else{'Red'})
    if($entry.missing){ Write-Host ("    missing: {0}" -f ($entry.missing -join ',')) -ForegroundColor Red }
  }
  return $obj
}

function Show-DataStreamsIfRequested {
  if($ShowDataStreams){
    Write-Host "[ES] Data streams actuales (requiere credenciales admin si seguridad restringe):" -ForegroundColor Yellow
    $headers = New-Headers -u $AdminUser -p $AdminPassword
    try{
      $ds = Invoke-WebRequest -Uri "$ElasticUrl/_data_stream?pretty" -Headers $headers -Method GET -UseBasicParsing
      Write-Host $ds.Content
    }catch{
      Write-Warning "No se pudo leer /_data_stream. Revisa credenciales admin o estado de ES."
    }
  }
}

Write-Host "[Run] Probando privilegios de índice para patrones: $($IndexPatterns -join ', ')" -ForegroundColor Cyan
$result = Test-Privileges -patterns $IndexPatterns -privs $Privileges

if(-not $result.has_all_requested){
  Write-Host "[Hint] Algunos privilegios no están concedidos. Asegúrate de que el rol del usuario incluya: $($Privileges -join ', ') sobre $($IndexPatterns -join ', ')." -ForegroundColor Red
  Write-Host "[Hint] Revisa docs/apm-permissions-guide.md para crear/ajustar el rol 'apm_writer_role'." -ForegroundColor DarkYellow
}

Show-DataStreamsIfRequested

Write-Host "[Done] Verificación completada." -ForegroundColor Green