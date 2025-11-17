param(
  [string]$Container = 'patroni-master',
  [int]$Port = 5432,
  [string]$Db = 'sasdatqbox',
  [string]$User = 'sas_user',
  [string]$Password = 'ML!gsx90l02',
  [string]$Schemas = 'public,pos',
  [string[]]$Actions = @('info','validate'),
  [switch]$Test,
  [string]$Network,
  [switch]$PreviewOnly,
  [switch]$ValidateOnMigrate,
  [string]$BaselineVersion,
  [switch]$BaselineOnMigrate,
  [string]$BaselineDescription = 'Baseline'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Ensure-Command {
  param([string]$Name)
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) { throw "Comando requerido no encontrado: $Name" }
}

function Get-RepoRoot { (Get-Location).Path }

function Detect-DockerNetwork {
  param([string]$Container)
  $json = docker inspect $Container | ConvertFrom-Json
  if (-not $json) { throw "Contenedor no encontrado: $Container" }
  $nets = @()
  $json[0].NetworkSettings.Networks.PSObject.Properties | ForEach-Object { $nets += $_.Name }
  if ($nets.Count -eq 0) { throw "El contenedor '$Container' no tiene redes asociadas" }
  return $nets[0]
}

Ensure-Command docker
if (-not $Password) { $Password = $env:PROD_DB_PASSWORD }
if (-not $Password) { throw "Falta contraseña: pase -Password o establezca ENV PROD_DB_PASSWORD" }

$root = Get-RepoRoot
$relMig = if ($Test) { 'src\main\resources\db\migration-test' } else { 'src\main\resources\db\migration' }
$migPath = Join-Path $root $relMig
$cbPath  = Join-Path $root 'src\main\resources\db\callbacks'
$locationsWin = @("filesystem:$migPath", "filesystem:$cbPath")
$locationsDocker = $locationsWin | ForEach-Object { ($_ -replace [regex]::Escape($root), '/workspace') -replace '\\','/' }

if (-not $Network) { $Network = Detect-DockerNetwork -Container $Container }

# Preflight: revisión de migraciones
$reviewScript = Join-Path $root 'scripts\review-migrations.sh'
if (Test-Path $reviewScript) {
  Write-Host "[Preflight] Revisando migraciones en $migPath" -ForegroundColor Cyan
  $env:MIG_DIR = if ($Test) { 'src/main/resources/db/migration-test' } else { 'src/main/resources/db/migration' }
  $env:SCHEMA = 'pos'
  $env:EXIT_ON_WARN = '0'
  $bash = Get-Command bash -ErrorAction SilentlyContinue
  if ($bash) { Push-Location $root; try { & bash './scripts/review-migrations.sh' } finally { Pop-Location } } else { Write-Warning 'bash no disponible; se omite preflight.' }
}

if ($PreviewOnly) { Write-Host "[Preflight] Modo solo revisión; no se ejecutará Flyway." -ForegroundColor Yellow; return }

$reports = Join-Path $root 'target\flyway\reports'
if (-not (Test-Path $reports)) { $null = New-Item -ItemType Directory -Path $reports }
$ts = (Get-Date).ToString('yyyyMMdd_HHmmss')

foreach ($action in $Actions) {
  $args = @(
    'run','--rm','--network',$Network,
    '-v',"${root}:/workspace",'-w','/workspace','flyway/flyway:10.10',
    $action,
    "-url=jdbc:postgresql://${Container}:$Port/${Db}",
    "-user=${User}",
    "-password=${Password}",
    "-schemas=${Schemas}",
    "-locations=$($locationsDocker -join ',')",
    '-outputType=json'
  )
  if ($ValidateOnMigrate) { $args += '-validateOnMigrate=true' }
  if ($BaselineOnMigrate) { $args += '-baselineOnMigrate=true' }
  if ($BaselineVersion) { $args += "-baselineVersion=$BaselineVersion" }
  if ($BaselineDescription) { $args += "-baselineDescription=$BaselineDescription" }
  Write-Host "[RUN] docker $($args -join ' ')" -ForegroundColor DarkGray
  $out = & docker @args 2>&1
  $file = Join-Path $reports "patroni-$action-$ts.json"
  $out | Set-Content -Path $file -Encoding UTF8
  Write-Host "[OK] Reporte: $file" -ForegroundColor Green
}

Write-Host "Listo. Reportes en $reports" -ForegroundColor Cyan