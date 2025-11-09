Param(
  [string]$KibanaUrl = 'http://localhost:5601',
  [string]$User = 'elastic',
  [string]$Password = 'changeme'
)

$auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$User`:$Password"))
$headers = @{ 'Authorization' = "Basic $auth"; 'kbn-xsrf' = 'true'; 'Content-Type' = 'application/json' }

Write-Host "[SETUP] Creando visualizaciones (Vega) y dashboard en Kibana" -ForegroundColor Cyan

$indexPatternId = 'backend-events'

# --- Visualización 1: Eventos por minuto (línea) ---
$vegaSpec1 = @'
{
  "$schema": "https://vega.github.io/schema/vega-lite/v5.json",
  "data": {
    "url": { "%context%": true, "%timefield%": "@timestamp", "index": "backend.events-*", "body": { "size": 0, "aggs": { "per_min": { "date_histogram": { "field": "@timestamp", "calendar_interval": "1m" } } } } },
    "format": { "property": "aggregations.per_min.buckets" }
  },
  "mark": "line",
  "encoding": {
    "x": { "field": "key", "type": "temporal", "title": "time" },
    "y": { "field": "doc_count", "type": "quantitative", "title": "events" }
  }
}
'@

$visState1 = @{ title = 'Eventos/min backend (Vega)'; type = 'vega'; params = @{ spec = $vegaSpec1 } } | ConvertTo-Json -Depth 50
$searchSource1 = @{ index = $indexPatternId; query = @{ language = 'kuery'; query = '' }; filter = @() } | ConvertTo-Json -Depth 10

$body1 = @{ 
  attributes = @{ 
    title = 'Eventos/min backend (Vega)';
    description = 'Eventos por minuto en backend.events-*';
    visState = $visState1;
    kibanaSavedObjectMeta = @{ searchSourceJSON = $searchSource1 } 
  };
  references = @(@{ id = $indexPatternId; name = 'kibanaSavedObjectMeta.searchSourceJSON.index'; type = 'index-pattern' })
} | ConvertTo-Json -Depth 50

$resp1 = Invoke-RestMethod -Method Post -Uri "$KibanaUrl/api/saved_objects/visualization" -Headers $headers -Body $body1
$vis1Id = $resp1.id
Write-Host "[OK] Visualización 1 creada (id: $vis1Id)" -ForegroundColor Green

# --- Visualización 2: Latencia media por endpoint (barras) ---
$vegaSpec2 = @'
{
  "$schema": "https://vega.github.io/schema/vega-lite/v5.json",
  "data": {
    "url": { "%context%": true, "%timefield%": "@timestamp", "index": "backend.events-*", "body": { "size": 0, "aggs": { "by_ep": { "terms": { "field": "endpoint.keyword", "size": 10 }, "aggs": { "lat": { "avg": { "field": "latency_ms" } } } } } } },
    "format": { "property": "aggregations.by_ep.buckets" }
  },
  "mark": "bar",
  "encoding": {
    "x": { "field": "key", "type": "nominal", "title": "endpoint" },
    "y": { "field": "lat.value", "type": "quantitative", "title": "avg latency (ms)" }
  }
}
'@

$visState2 = @{ title = 'Latencia media por endpoint (Vega)'; type = 'vega'; params = @{ spec = $vegaSpec2 } } | ConvertTo-Json -Depth 50
$searchSource2 = $searchSource1

$body2 = @{ 
  attributes = @{ 
    title = 'Latencia media por endpoint (Vega)';
    description = 'Average latency por endpoint en backend.events-*';
    visState = $visState2;
    kibanaSavedObjectMeta = @{ searchSourceJSON = $searchSource2 } 
  };
  references = @(@{ id = $indexPatternId; name = 'kibanaSavedObjectMeta.searchSourceJSON.index'; type = 'index-pattern' })
} | ConvertTo-Json -Depth 50

$resp2 = Invoke-RestMethod -Method Post -Uri "$KibanaUrl/api/saved_objects/visualization" -Headers $headers -Body $body2
$vis2Id = $resp2.id
Write-Host "[OK] Visualización 2 creada (id: $vis2Id)" -ForegroundColor Green

# --- Visualización 3: Monto promedio por endpoint (barras) ---
$vegaSpec3 = @'
{
  "$schema": "https://vega.github.io/schema/vega-lite/v5.json",
  "data": {
    "url": { "%context%": true, "%timefield%": "@timestamp", "index": "backend.events-*", "body": { "size": 0, "aggs": { "by_ep": { "terms": { "field": "endpoint.keyword", "size": 10 }, "aggs": { "amt": { "avg": { "field": "amount" } } } } } } },
    "format": { "property": "aggregations.by_ep.buckets" }
  },
  "mark": "bar",
  "encoding": {
    "x": { "field": "key", "type": "nominal", "title": "endpoint" },
    "y": { "field": "amt.value", "type": "quantitative", "title": "avg amount" }
  }
}
'@

$visState3 = @{ title = 'Monto promedio por endpoint (Vega)'; type = 'vega'; params = @{ spec = $vegaSpec3 } } | ConvertTo-Json -Depth 50
$searchSource3 = $searchSource1

$body3 = @{ 
  attributes = @{ 
    title = 'Monto promedio por endpoint (Vega)';
    description = 'Average amount por endpoint en backend.events-*';
    visState = $visState3;
    kibanaSavedObjectMeta = @{ searchSourceJSON = $searchSource3 } 
  };
  references = @(@{ id = $indexPatternId; name = 'kibanaSavedObjectMeta.searchSourceJSON.index'; type = 'index-pattern' })
} | ConvertTo-Json -Depth 50

$resp3 = Invoke-RestMethod -Method Post -Uri "$KibanaUrl/api/saved_objects/visualization" -Headers $headers -Body $body3
$vis3Id = $resp3.id
Write-Host "[OK] Visualización 3 creada (id: $vis3Id)" -ForegroundColor Green

# --- Dashboard con las dos visualizaciones ---
$panels = @(
  @{ version = '8.14.0'; type = 'visualization'; panelIndex = '1'; gridData = @{ x = 0; y = 0; w = 24; h = 12; i = '1' }; panelRefName = 'panel_0' },
  @{ version = '8.14.0'; type = 'visualization'; panelIndex = '2'; gridData = @{ x = 24; y = 0; w = 24; h = 12; i = '2' }; panelRefName = 'panel_1' },
  @{ version = '8.14.0'; type = 'visualization'; panelIndex = '3'; gridData = @{ x = 0; y = 12; w = 48; h = 12; i = '3' }; panelRefName = 'panel_2' }
) | ConvertTo-Json -Depth 20

$dashBody = @{ 
  attributes = @{ 
    title = 'Backend Observability';
    description = 'Eventos y latencia del backend';
    panelsJSON = $panels;
    optionsJSON = (@{ useMargins = $true; syncColors = $false } | ConvertTo-Json);
    timeRestore = $false;
    kibanaSavedObjectMeta = @{ searchSourceJSON = (@{ index = $indexPatternId; query = @{ language = 'kuery'; query = '' }; filter = @() } | ConvertTo-Json -Depth 10) }
  };
  references = @(
    @{ id = $vis1Id; name = 'panel_0'; type = 'visualization' },
    @{ id = $vis2Id; name = 'panel_1'; type = 'visualization' },
    @{ id = $vis3Id; name = 'panel_2'; type = 'visualization' }
  )
} | ConvertTo-Json -Depth 50

$dashResp = Invoke-RestMethod -Method Post -Uri "$KibanaUrl/api/saved_objects/dashboard" -Headers $headers -Body $dashBody
$dashId = $dashResp.id
Write-Host "[OK] Dashboard creado: Backend Observability (id: $dashId)" -ForegroundColor Green
Write-Host "[OPEN] $KibanaUrl/app/dashboards#/view/$dashId" -ForegroundColor Cyan