<#
.SYNOPSIS
  Ejecuta acciones de Flyway (clean, migrate, info, validate) en múltiples bases de datos, leyendo parámetros JSON.

.DESCRIPTION
  Inspirado en el artículo de Redgate, este runner permite:
  - Definir parámetros comunes y específicos por BD en archivos JSON.
  - Ejecutar la misma secuencia de acciones en todas las BDs (p.ej., clean+migrate+info).
  - Capturar la salida en JSON por BD y guardar reportes.
  - Usar Flyway CLI instalado localmente o vía Docker (flyway/flyway).
  - Ejecutar una revisión previa de migraciones con scripts/review-migrations.sh.

.PARAMETER ParamsDir
  Directorio con archivos .json de parámetros (uno por BD). Por defecto scripts/flyway/params.

.PARAMETER Only
  Lista de nombres de BDs a ejecutar (filtra por campo "name" en JSON).

.PARAMETER UseDocker
  Fuerza el uso de Docker flyway/flyway en lugar de CLI local.

.PARAMETER DryRun
  Muestra las acciones que se ejecutarían, sin ejecutar Flyway.

.PARAMETER SkipClean
  Omite la acción "clean" aunque esté listada en el JSON.

.NOTES
  - No guardes contraseñas en JSON. Usa el campo "passwordEnv" para indicar la variable de entorno donde está la clave.
  - Ejemplo de JSON en scripts/flyway/params/example.json.
#>

param(
  [string]$ParamsDir = "scripts/flyway/params",
  [string[]]$Only = @(),
  [switch]$UseDocker,
  [switch]$DryRun,
  [switch]$SkipClean,
  [switch]$Test,
  [switch]$PreflightOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Ensure-Dir {
  param([string]$Path)
  if (-not (Test-Path $Path -PathType Container)) { $null = New-Item -ItemType Directory -Path $Path }
}

function Get-RepoRoot {
  return (Get-Location).Path
}

function Get-FlywayCLI {
  param([switch]$UseDocker)
  $flyway = Get-Command flyway -ErrorAction SilentlyContinue
  if ($UseDocker -or -not $flyway) {
    $docker = Get-Command docker -ErrorAction SilentlyContinue
    if (-not $docker) { throw "Flyway CLI no encontrado y Docker no disponible. Instala Flyway o Docker." }
    return @{ kind = 'docker'; cmd = 'docker'; image = 'flyway/flyway:10.10' }
  } else {
    return @{ kind = 'cli'; cmd = $flyway.Source }
  }
}

function Get-FlywayLocations {
  param([string[]]$Locations, [switch]$Test)
  if ($Locations -and $Locations.Count -gt 0) { return $Locations }
  $root = Get-RepoRoot
  $mig = if ($Test) { Join-Path $root 'src\main\resources\db\migration-test' } else { Join-Path $root 'src\main\resources\db\migration' }
  $cb  = Join-Path $root 'src\main\resources\db\callbacks'
  return @("filesystem:$mig", "filesystem:$cb")
}

function Invoke-Flyway {
  param(
    [hashtable]$Db,
    [hashtable]$Cli,
    [switch]$SkipClean
  )

  $name = $Db.name
  $url = $Db.url
  $user = $Db.user
  $pwdEnv = $Db.passwordEnv
  $password = if ($pwdEnv) { (Get-Item "Env:$pwdEnv").Value } else { $Db.password }
  if (-not $password) { throw "[$name] Falta contraseña (usa 'passwordEnv' en JSON o establece 'password')." }

  $schemas = if ($Db.schemas) { ($Db.schemas -join ',') } else { 'public,pos' }
  $actions = if ($Db.actions) { $Db.actions } else { @('migrate','info') }
  $locations = Get-FlywayLocations -Locations $Db.locations -Test:$Test
  $placeholders = $Db.placeholders
  $validate = if ($Db.validate) { [bool]$Db.validate } else { $true }

  $root = Get-RepoRoot
  $reportsDir = Join-Path $root 'target\flyway\reports'
  Ensure-Dir $reportsDir
  $timestamp = (Get-Date).ToString('yyyyMMdd_HHmmss')

  Write-Host "[$name] URL=$url Schemas=$schemas Actions=$($actions -join ',')" -ForegroundColor Cyan

  foreach ($action in $actions) {
    if ($SkipClean -and $action -eq 'clean') { Write-Host "[$name] Omite 'clean'" -ForegroundColor Yellow; continue }

    $commonArgs = @(
      "-url=$url",
      "-user=$user",
      "-password=$password",
      "-schemas=$schemas",
      "-locations=$($locations -join ',')",
      "-outputType=json"
    )
    if ($validate) { $commonArgs += "-validateOnMigrate=true" }
    if ($placeholders) {
      $placeholders.GetEnumerator() | ForEach-Object { $commonArgs += "-placeholders.$($_.Key)=$($_.Value)" }
    }

    $reportPath = Join-Path $reportsDir "$name-$action-$timestamp.json"

    if ($Cli.kind -eq 'cli') {
      $args = @($action) + $commonArgs
      if ($DryRun) {
        Write-Host "[DRY] flyway $($args -join ' ')" -ForegroundColor DarkGray
        continue
      }
      $out = & $Cli.cmd @args 2>&1
      $out | Set-Content -Path $reportPath -Encoding UTF8
    } else {
      $rootLinux = '/workspace'
      $locationsDocker = $locations | ForEach-Object { $_.Replace((Get-RepoRoot), $rootLinux) } | ForEach-Object { $_.Replace('\','/') }
      $dockerArgs = @(
        'run','--rm','-v',"$(Get-Location):$rootLinux",'-w',$rootLinux,$Cli.image,
        $action
      ) + @(
        "-url=$url",
        "-user=$user",
        "-password=$password",
        "-schemas=$schemas",
        "-locations=$($locationsDocker -join ',')",
        "-outputType=json"
      )
      if ($validate) { $dockerArgs += "-validateOnMigrate=true" }
      if ($placeholders) {
        $placeholders.GetEnumerator() | ForEach-Object { $dockerArgs += "-placeholders.$($_.Key)=$($_.Value)" }
      }
      if ($DryRun) {
        Write-Host "[DRY] docker $($dockerArgs -join ' ')" -ForegroundColor DarkGray
        continue
      }
      $out = & docker @dockerArgs 2>&1
      $out | Set-Content -Path $reportPath -Encoding UTF8
    }

    Write-Host "[$name] Reporte: $reportPath" -ForegroundColor Green
  }
}

function Load-DbParams {
  param([string]$ParamsDir)
  if (-not (Test-Path $ParamsDir -PathType Container)) {
    throw "Directorio de parámetros no existe: $ParamsDir"
  }
  $files = Get-ChildItem -Path $ParamsDir -Filter *.json
  $dbs = @()
  foreach ($f in $files) { $dbs += (Get-Content $f.FullName | ConvertFrom-Json) }
  return $dbs
}

# Revisión previa de migraciones
$reviewScript = Join-Path (Get-RepoRoot) 'scripts\review-migrations.sh'
$reviewScriptLinux = $reviewScript -replace '\\','/'
if (Test-Path $reviewScript) {
Write-Host "[Preflight] Ejecutando revisión de migraciones..." -ForegroundColor Cyan
  $env:MIG_DIR = if ($Test) { 'src/main/resources/db/migration-test' } else { 'src/main/resources/db/migration' }
  $env:SCHEMA = 'pos'
  $env:EXIT_ON_WARN = '0'
  $bashCmd = Get-Command bash -ErrorAction SilentlyContinue
  if ($bashCmd) {
    Push-Location (Get-RepoRoot)
    try { & bash './scripts/review-migrations.sh' } catch { Write-Warning "No se pudo ejecutar bash para la revisión: $_" }
    Pop-Location
  } else {
    Write-Warning "bash no está disponible en este entorno; se omite la revisión previa."
  }
  if ($PreflightOnly) {
    Write-Host "[Preflight] Modo solo revisión activo; no se ejecutarán acciones de Flyway." -ForegroundColor Yellow
    return
  }
}

$cli = Get-FlywayCLI -UseDocker:$UseDocker
$dbs = Load-DbParams -ParamsDir $ParamsDir
if ($Only.Count -gt 0) { $dbs = $dbs | Where-Object { $_.name -in $Only } }
if ($dbs.Count -eq 0) { throw "No hay archivos de parámetros (.json) en $ParamsDir" }

foreach ($db in $dbs) { Invoke-Flyway -Db $db -Cli $cli -SkipClean:$SkipClean }

Write-Host "Listo. Revisa los reportes en target/flyway/reports" -ForegroundColor Cyan