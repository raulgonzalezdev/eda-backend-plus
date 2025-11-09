Param(
  [string]$KibanaUrl = 'http://localhost:5601',
  [string]$User = 'elastic',
  [string]$Password = 'changeme'
)

$auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$User`:$Password"))
$headers = @{ 'Authorization' = "Basic $auth"; 'kbn-xsrf' = 'true'; 'Content-Type' = 'application/json' }

Write-Host "[SETUP] Creando Data View y búsqueda guardada para backend.events-* en Kibana ($KibanaUrl)" -ForegroundColor Cyan

# 1) Crear Data View (index-pattern) con id fijo
$indexPatternId = 'backend-events'
$indexPatternBody = @{
  attributes = @{ title = 'backend.events-*'; timeFieldName = '@timestamp' }
} | ConvertTo-Json -Depth 5

try {
  Invoke-RestMethod -Method Post -Uri "$KibanaUrl/api/saved_objects/index-pattern/$indexPatternId" -Headers $headers -Body $indexPatternBody | Out-Null
  Write-Host "[OK] Data View creada: backend.events-* (id: $indexPatternId)" -ForegroundColor Green
} catch {
  Write-Host "[INFO] Data View ya existe o fue creada anteriormente (id: $indexPatternId)" -ForegroundColor Yellow
}

# 2) Crear Saved Search en Discover
$searchTitle = 'Últimos eventos backend'
$searchSource = @{ 
  index = $indexPatternId;
  query = @{ language = 'kuery'; query = 'pipeline: "backend_events"' };
  filter = @();
  sort = @(@('@timestamp','desc'))
} | ConvertTo-Json -Depth 8

$searchBody = @{ 
  attributes = @{ 
    title = $searchTitle;
    description = 'Eventos recientes del pipeline backend_events';
    columns = @('@timestamp','endpoint','latency_ms','status_code','user_id','amount','pipeline');
    sort = @(@('@timestamp','desc'));
    kibanaSavedObjectMeta = @{ searchSourceJSON = $searchSource }
  };
  references = @(@{ id = $indexPatternId; name = 'kibanaSavedObjectMeta.searchSourceJSON.index'; type = 'index-pattern' })
} | ConvertTo-Json -Depth 10

try {
  $resp = Invoke-RestMethod -Method Post -Uri "$KibanaUrl/api/saved_objects/search" -Headers $headers -Body $searchBody
  $searchId = $resp.id
  Write-Host "[OK] Saved Search creada: $searchTitle (id: $searchId)" -ForegroundColor Green
} catch {
  Write-Host "[INFO] Saved Search quizá ya exista. Puedes buscarla por título en Discover." -ForegroundColor Yellow
}

Write-Host "[DONE] Abre Discover: $KibanaUrl/app/discover y selecciona la Data View 'backend.events'" -ForegroundColor Cyan
Write-Host "       También puedes abrir Data Views: $KibanaUrl/app/management/kibana/dataViews" -ForegroundColor Cyan