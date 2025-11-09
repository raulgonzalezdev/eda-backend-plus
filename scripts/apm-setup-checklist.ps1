Param(
  [string]$ElasticUrl = 'http://localhost:9200',
  [string]$KibanaUrl  = 'http://localhost:5601',
  [string]$ElasticUser = 'elastic',
  [string]$ElasticPassword = 'changeme',
  [string]$RoleName = 'apm_writer_role',
  [string]$UserName = 'apm_writer',
  [string]$UserPassword = 'changemeAPMWRITER',
  [string]$ApmPackageVersion = '8.14.0'
)

Write-Host "[APM] Checklist de configuración y verificación" -ForegroundColor Cyan

function New-EsHeaders([string]$user, [string]$pass) {
  $b64 = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$user:$pass"))
  return @{ Authorization = "Basic $b64"; 'Content-Type'='application/json' }
}

function Invoke-Es([string]$uri, [string]$method = 'GET', [string]$body = $null) {
  $headers = New-EsHeaders -user $ElasticUser -pass $ElasticPassword
  if ($null -ne $body) {
    return Invoke-WebRequest -Uri $uri -Method $method -Headers $headers -Body $body -UseBasicParsing
  } else {
    return Invoke-WebRequest -Uri $uri -Method $method -Headers $headers -UseBasicParsing
  }
}

function Create-ApmWriterRole {
  Write-Host "[APM] Creando rol '$RoleName' en Elasticsearch..." -ForegroundColor Yellow
  $roleBody = '{
    "cluster": ["monitor"],
    "indices": [
      { "names": ["logs-apm*","metrics-apm*","traces-apm*"], "privileges": ["auto_configure","create_index","write","create_doc"] }
    ]
  }'
  $resp = Invoke-Es -uri "$ElasticUrl/_security/role/$RoleName" -method 'PUT' -body $roleBody
  Write-Host $resp.Content
}

function Create-ApmWriterUser {
  Write-Host "[APM] Creando usuario '$UserName' en Elasticsearch..." -ForegroundColor Yellow
  $userBody = "{ \"password\": \"$UserPassword\", \"roles\": [\"$RoleName\"] }"
  $resp = Invoke-Es -uri "$ElasticUrl/_security/user/$UserName" -method 'POST' -body $userBody
  Write-Host $resp.Content
}

function Verify-RoleAndUser {
  Write-Host "[APM] Verificando rol y usuario..." -ForegroundColor Yellow
  $r = Invoke-Es -uri "$ElasticUrl/_security/role/$RoleName"
  Write-Host "Rol:", $r.Content
  $u = Invoke-Es -uri "$ElasticUrl/_security/user/$UserName"
  Write-Host "Usuario:", $u.Content
}

function Kibana-Status {
  Write-Host "[Kibana] Consultando /api/status..." -ForegroundColor Yellow
  $headers = New-EsHeaders -user $ElasticUser -pass $ElasticPassword
  $resp = Invoke-WebRequest -Uri "$KibanaUrl/api/status" -Headers $headers -UseBasicParsing -Method GET
  Write-Host $resp.Content
}

function Fleet-Setup {
  Write-Host "[Fleet] Inicializando Fleet (si no lo está)..." -ForegroundColor Yellow
  $headers = New-EsHeaders -user $ElasticUser -pass $ElasticPassword
  $resp = Invoke-WebRequest -Uri "$KibanaUrl/api/fleet/setup" -Method POST -Headers $headers -Body '{}' -UseBasicParsing
  Write-Host $resp.Content
}

function Install-ApmPackage {
  Write-Host "[Fleet] Instalando paquete APM $ApmPackageVersion (si aplica)..." -ForegroundColor Yellow
  $headers = New-EsHeaders -user $ElasticUser -pass $ElasticPassword
  $uri = "$KibanaUrl/api/fleet/epm/packages/apm/$ApmPackageVersion"
  $resp = Invoke-WebRequest -Uri $uri -Method POST -Headers $headers -Body '{}' -UseBasicParsing
  Write-Host $resp.Content
}

function Verify-DataStreams {
  Write-Host "[ES] Listando data streams..." -ForegroundColor Yellow
  $resp = Invoke-Es -uri "$ElasticUrl/_data_stream?pretty"
  Write-Host $resp.Content
}

function Create-ApmApiKey {
  Write-Host "[APM] Creando API key para apm-server (opcional)..." -ForegroundColor Yellow
  $body = '{
    "name": "apm-server-key",
    "role_descriptors": {
      "apm_writer": {
        "cluster": ["monitor"],
        "index": [
          { "names": ["logs-apm*","metrics-apm*","traces-apm*"], "privileges": ["auto_configure","create_doc","write","create_index"] }
        ]
      }
    }
  }'
  $resp = Invoke-Es -uri "$ElasticUrl/_security/api_key" -method 'POST' -body $body
  $parsed = ConvertFrom-Json $resp.Content
  $pair = $parsed.id + ':' + $parsed.api_key
  $b64 = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($pair))
  Write-Host "[APM] api_key base64 (para apm-server):", $b64 -ForegroundColor Green
}

Write-Host "[Run] Paso 1: crear rol y usuario" -ForegroundColor Cyan
Create-ApmWriterRole
Create-ApmWriterUser
Verify-RoleAndUser

Write-Host "[Run] Paso 2: verificar Kibana y Fleet" -ForegroundColor Cyan
Kibana-Status
Fleet-Setup

Write-Host "[Run] Paso 3: instalar paquete APM (si no está)" -ForegroundColor Cyan
Install-ApmPackage

Write-Host "[Run] Paso 4: verificar data streams (tras generar tráfico)" -ForegroundColor Cyan
Verify-DataStreams

Write-Host "[Optional] Crear API key para apm-server" -ForegroundColor Cyan
Create-ApmApiKey

Write-Host "[Done] Revisa logs de apm-server para 200 en /v1/* y data streams activos." -ForegroundColor Green