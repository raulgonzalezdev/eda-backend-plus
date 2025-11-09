# Guía de Configuración de Permisos APM (Paso a Paso)

Esta guía documenta las URLs y cuerpos exactos que debes invocar para configurar `apm-server` con permisos mínimos y verificaciones. Usa `elastic/changeme` para autenticación básica (ajusta si cambiaste la contraseña).

## 1. Crear rol `apm_writer_role`
- Endpoint: `PUT http://localhost:9200/_security/role/apm_writer_role`
- Body:
```json
{
  "cluster": ["monitor"],
  "indices": [
    { "names": ["logs-apm*","metrics-apm*","traces-apm*"],
      "privileges": ["auto_configure","create_index","write","create_doc"] }
  ]
}
```
- PowerShell:
```powershell
$auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes('elastic:changeme'))
$headers = @{ Authorization = "Basic $auth"; 'Content-Type'='application/json' }
$roleBody = '{ "cluster":["monitor"], "indices":[ { "names":["logs-apm*","metrics-apm*","traces-apm*"], "privileges":["auto_configure","create_index","write","create_doc"] } ] }'
Invoke-WebRequest -Uri http://localhost:9200/_security/role/apm_writer_role -Method PUT -Headers $headers -Body $roleBody -UseBasicParsing
```

## 2. Crear usuario `apm_writer`
- Endpoint: `POST http://localhost:9200/_security/user/apm_writer`
- Body:
```json
{ "password": "changemeAPMWRITER", "roles": ["apm_writer_role"] }
```
- PowerShell:
```powershell
$userBody = '{ "password": "changemeAPMWRITER", "roles": ["apm_writer_role"] }'
Invoke-WebRequest -Uri http://localhost:9200/_security/user/apm_writer -Method POST -Headers $headers -Body $userBody -UseBasicParsing
```
- Verificar:
```powershell
Invoke-WebRequest -Uri http://localhost:9200/_security/role/apm_writer_role -Headers $headers -UseBasicParsing
Invoke-WebRequest -Uri http://localhost:9200/_security/user/apm_writer -Headers $headers -UseBasicParsing
```

## 3. Configurar `apm-server`
En `config/apm-server.yml`:
```yaml
output.elasticsearch:
  hosts: ["http://elasticsearch:9200"]
  protocol: "http"
  username: "apm_writer"
  password: "changemeAPMWRITER"
```
Reiniciar cuando lo decidas:
```powershell
docker compose restart apm-server
```
Logs esperados: desaparición de 401/403 y `handled request ... 200` en `/v1/traces`, `/v1/logs`, `/v1/metrics`.

## 4. Inicializar Fleet e instalar APM (si aplica)
- Kibana status:
```powershell
Invoke-WebRequest -Uri http://localhost:5601/api/status -Headers $headers -UseBasicParsing
```
- Fleet setup:
```powershell
Invoke-WebRequest -Uri http://localhost:5601/api/fleet/setup -Method POST -Headers $headers -Body '{}' -UseBasicParsing
```
- Instalar APM Package (ej. 8.14.0):
```powershell
Invoke-WebRequest -Uri http://localhost:5601/api/fleet/epm/packages/apm/8.14.0 -Method POST -Headers $headers -Body '{}' -UseBasicParsing
```

## 5. Verificar data streams en Elasticsearch
```powershell
Invoke-WebRequest -Uri http://localhost:9200/_data_stream?pretty -Headers $headers -UseBasicParsing
```
Debes ver `logs-apm*`, `metrics-apm*`, `traces-apm*` cuando ya hay tráfico de agentes.

## 6. Alternativa: API key para `apm-server` (opcional)
- Endpoint: `POST http://localhost:9200/_security/api_key`
- Body:
```json
{
  "name": "apm-server-key",
  "role_descriptors": {
    "apm_writer": {
      "cluster": ["monitor"],
      "index": [
        { "names": ["logs-apm*","metrics-apm*","traces-apm*"],
          "privileges": ["auto_configure","create_doc","write","create_index"] }
      ]
    }
  }
}
```
- PowerShell:
```powershell
$body = '{ "name":"apm-server-key","role_descriptors":{"apm_writer":{"cluster":["monitor"],"index":[{ "names":["logs-apm*","metrics-apm*","traces-apm*"], "privileges":["auto_configure","create_doc","write","create_index"] }]}}}'
$resp = Invoke-WebRequest -Uri http://localhost:9200/_security/api_key -Method POST -Headers $headers -Body $body -UseBasicParsing
$parsed = ConvertFrom-Json $resp.Content
$pair = $parsed.id + ':' + $parsed.api_key
$b64 = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($pair))
$b64  # Usa este base64 en apm-server.yml
```
En `apm-server.yml`:
```yaml
output.elasticsearch:
  api_key: "<base64(id:api_key)>"
```

## 7. Troubleshooting
- Error `401/403` en apm-server:
  - Revisar credenciales (usuario/clave o api_key en base64)
  - Confirmar rol con `auto_configure`, `create_index`, `write`, `create_doc` en `logs-apm*`, `metrics-apm*`, `traces-apm*`.
- Error `503 request timed out`:
  - Asegura que ES/Kibana están `available` y que apm-server puede llegar a ES.
- Data streams vacíos:
  - Genera tráfico desde agentes (o tu monolito). Sin tráfico, no aparecen.

---

Archivo relacionado (automatiza pasos): `scripts/apm-setup-checklist.ps1`