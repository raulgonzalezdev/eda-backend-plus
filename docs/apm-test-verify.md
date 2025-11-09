# Pruebas y Verificación de APM (Paso a Paso)

Este documento te guía para validar que APM (OpenTelemetry → apm-server → Elasticsearch → Kibana) está funcionando. No despliega nada; sólo genera tráfico y consulta estados.

## 1. Estado de Kibana
- Comando (PowerShell):
```powershell
Invoke-WebRequest -Uri http://localhost:5601/api/status -Headers @{ Authorization = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes('elastic:changeme')) } -UseBasicParsing
```
- Esperado: `overall.level: "available"`.

## 2. Generar tráfico
- Usa tu script existente que ya probaste:
```powershell
pwsh ./scripts/observability_smoke.ps1 -Count 20 -BaseUrl http://localhost:8080
```
- Esto llama endpoints del backend y debería producir eventos y trazas.

## 3. Logs de apm-server
```powershell
docker compose logs --tail=200 apm-server
```
- Esperado: `handled request` con `http.response.status_code 200` en `/v1/traces`, `/v1/metrics`, `/v1/logs`.
- Si ves `unauthorized ... auto_create`, revisa permisos del usuario de salida (`apm_writer_role`).

## 4. Data Streams e índices
- Data streams:
```powershell
Invoke-WebRequest -Uri http://localhost:9200/_data_stream?pretty -Headers @{ Authorization = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes('elastic:changeme')) } -UseBasicParsing
```
- Índices por prefijo:
```powershell
Invoke-WebRequest -Uri http://localhost:9200/_cat/indices/logs-apm*?v -Headers @{ Authorization = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes('elastic:changeme')) } -UseBasicParsing
Invoke-WebRequest -Uri http://localhost:9200/_cat/indices/metrics-apm*?v -Headers @{ Authorization = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes('elastic:changeme')) } -UseBasicParsing
Invoke-WebRequest -Uri http://localhost:9200/_cat/indices/traces-apm*?v -Headers @{ Authorization = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes('elastic:changeme')) } -UseBasicParsing
```
- Esperado: entradas para `traces-apm*`, `metrics-apm*`, `logs-apm*`.

## 5. URLs útiles en Kibana
- Services (APM):
```
http://localhost:5601/app/apm/services?rangeFrom=now-30m&rangeTo=now
```
- Discover (traces):
```
http://localhost:5601/app/discover#/?_a=(index:'traces-apm*')
```

## 6. Script automatizado (opcional)
- Usa `scripts/apm-test-verify.ps1` para ejecutar todo en orden:
```powershell
pwsh ./scripts/apm-test-verify.ps1 -Count 20 -BaseUrl http://localhost:8080
```

## Troubleshooting rápido
- 401/403 al indexar:
  - Verifica que `apm-server` usa usuario `apm_writer` o API key base64 con privilegios en `logs-apm*`, `metrics-apm*`, `traces-apm*`.
- 503 request timed out:
  - Asegúrate de que Elasticsearch/Kibana están `available` y que `apm-server` llega a ES.
- No aparecen data streams:
  - Genera tráfico; sin datos no se crean.

---

Documentos relacionados:
- `docs/apm-permissions-guide.md` (permisos y roles)
- `scripts/apm-setup-checklist.ps1` (setup y verificación)