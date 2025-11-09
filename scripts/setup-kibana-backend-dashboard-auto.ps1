Param(
  [string]$KibanaUrl = 'http://localhost:5601',
  [string]$User = 'elastic',
  [string]$Password = 'changeme'
)

$auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$User`:$Password"))
$headers = @{ 'Authorization' = "Basic $auth"; 'kbn-xsrf' = 'true'; 'Content-Type' = 'application/json' }

Write-Host "[SETUP] Creando visualizaciones (Vega) y dashboard (auto-refresh + 15m)" -ForegroundColor Cyan

$indexPatternId = 'backend-events'

# --- Visual 1: Eventos/min ---
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
$body1 = @{ attributes = @{ title = 'Eventos/min backend (Vega)'; description = 'Eventos por minuto'; visState = $visState1; kibanaSavedObjectMeta = @{ searchSourceJSON = $searchSource1 } }; references = @(@{ id = $indexPatternId; name = 'kibanaSavedObjectMeta.searchSourceJSON.index'; type = 'index-pattern' }) } | ConvertTo-Json -Depth 50
$resp1 = Invoke-RestMethod -Method Post -Uri "$KibanaUrl/api/saved_objects/visualization" -Headers $headers -Body $body1
$vis1Id = $resp1.id

# --- Visual 2: Latencia media por endpoint ---
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
$body2 = @{ attributes = @{ title = 'Latencia media por endpoint (Vega)'; description = 'Promedio de latencia'; visState = $visState2; kibanaSavedObjectMeta = @{ searchSourceJSON = $searchSource1 } }; references = @(@{ id = $indexPatternId; name = 'kibanaSavedObjectMeta.searchSourceJSON.index'; type = 'index-pattern' }) } | ConvertTo-Json -Depth 50
$resp2 = Invoke-RestMethod -Method Post -Uri "$KibanaUrl/api/saved_objects/visualization" -Headers $headers -Body $body2
$vis2Id = $resp2.id

# --- Visual 3: Monto promedio por endpoint ---
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
$body3 = @{ attributes = @{ title = 'Monto promedio por endpoint (Vega)'; description = 'Promedio de montos'; visState = $visState3; kibanaSavedObjectMeta = @{ searchSourceJSON = $searchSource1 } }; references = @(@{ id = $indexPatternId; name = 'kibanaSavedObjectMeta.searchSourceJSON.index'; type = 'index-pattern' }) } | ConvertTo-Json -Depth 50
$resp3 = Invoke-RestMethod -Method Post -Uri "$KibanaUrl/api/saved_objects/visualization" -Headers $headers -Body $body3
$vis3Id = $resp3.id

# --- Dashboard: una fila con tres paneles, timeRestore=15m, auto-refresh=60s ---
$panels = @(
  @{ version = '8.14.0'; type = 'visualization'; panelIndex = '1'; gridData = @{ x = 0;  y = 0; w = 16; h = 12; i = '1' }; panelRefName = 'panel_0' },
  @{ version = '8.14.0'; type = 'visualization'; panelIndex = '2'; gridData = @{ x = 16; y = 0; w = 16; h = 12; i = '2' }; panelRefName = 'panel_1' },
  @{ version = '8.14.0'; type = 'visualization'; panelIndex = '3'; gridData = @{ x = 32; y = 0; w = 16; h = 12; i = '3' }; panelRefName = 'panel_2' }
) | ConvertTo-Json -Depth 20

$dashBody = @{ 
  attributes = @{ 
    title = 'Backend Observability (Auto)';
    description = 'Eventos/Latencia/Monto - 15m, auto-refresh 60s';
    panelsJSON = $panels;
    optionsJSON = (@{ useMargins = $true; syncColors = $false } | ConvertTo-Json);
    timeRestore = $true;
    timeFrom = 'now-15m';
    timeTo   = 'now';
    refreshInterval = @{ pause = $false; value = 60000 };
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
Write-Host "[OK] Dashboard creado: Backend Observability (Auto) (id: $dashId)" -ForegroundColor Green
Write-Host "[OPEN] $KibanaUrl/app/dashboards#/view/$dashId" -ForegroundColor Cyan