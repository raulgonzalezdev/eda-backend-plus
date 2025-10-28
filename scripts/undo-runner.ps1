<#
.SYNOPSIS
  Ejecuta Undo de migraciones:
  - Si Flyway Teams está disponible: usa 'flyway undo -target=<version>'.
  - Si no: aplica secuencialmente los scripts manuales 'src/main/resources/db/undo/U{version}__*.sql' usando psql (Docker).

.PARAMETER TargetVersion
  Versión a la que quieres volver (p.ej., 7). Si faltan U-scripts intermedios, se alerta.

.PARAMETER Url
  JDBC URL del Postgres (ej.: jdbc:postgresql://haproxy:5000/sasdatqbox?sslmode=disable)

.PARAMETER User
  Usuario DB.

.PARAMETER PasswordEnv
  Nombre de variable de entorno con la clave DB.

.PARAMETER Password
  Clave DB (usa PasswordEnv preferible).

.PARAMETER Schema
  Esquema para search_path (default 'pos').

.PARAMETER UseDocker
  Usa Flyway/psql vía Docker.

.EXAMPLE
  scripts/undo-runner.ps1 -TargetVersion 7 -Url jdbc:postgresql://haproxy:5000/sasdatqbox -User sas_user -PasswordEnv DB_PASSWORD
#>

param(
  [Parameter(Mandatory=$true)][int]$TargetVersion,
  [Parameter(Mandatory=$true)][string]$Url,
  [Parameter(Mandatory=$true)][string]$User,
  [string]$PasswordEnv,
  [string]$Password,
  [string]$Schema = 'pos',
  [switch]$UseDocker
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-RepoRoot { (Get-Location).Path }
function Ensure-Dir([string]$Path) { if (-not (Test-Path $Path -PathType Container)) { $null = New-Item -ItemType Directory -Path $Path } }

function Get-Password {
  if ($Password) { return $Password }
  if ($PasswordEnv) { return (Get-Item "Env:$PasswordEnv").Value }
  throw "Falta password: define -Password o -PasswordEnv"
}

function Get-FlywayCLI([switch]$UseDocker) {
  $flyway = Get-Command flyway -ErrorAction SilentlyContinue
  if ($UseDocker -or -not $flyway) {
    $docker = Get-Command docker -ErrorAction SilentlyContinue
    if (-not $docker) { throw "No hay Flyway CLI y Docker no disponible" }
    return @{ kind = 'docker'; cmd = 'docker'; image = 'flyway/flyway:10.10' }
  } else { return @{ kind = 'cli'; cmd = $flyway.Source } }
}

function Supports-Undo([hashtable]$Cli) {
  try {
    if ($Cli.kind -eq 'cli') {
      $help = & $Cli.cmd -? 2>&1
      return ($help -match '\bundo\b')
    } else {
      $out = & docker run --rm $Cli.image -? 2>&1
      return ($out -match '\bundo\b')
    }
  } catch { return $false }
}

function Flyway-InfoJson([hashtable]$Cli, [string]$Url, [string]$User, [string]$Password) {
  $args = @('info',"-url=$Url","-user=$User","-password=$Password","-outputType=json")
  if ($Cli.kind -eq 'cli') { return (& $Cli.cmd @args 2>&1) }
  else { return (& docker run --rm $Cli.image @args 2>&1) }
}

function Parse-CurrentVersion([string]$jsonText) {
  try {
    $obj = $jsonText | ConvertFrom-Json
    $applied = $obj.migrations | Where-Object { $_.state -eq 'Success' } | Select-Object -Last 1
    return [int]$applied.version
  } catch { throw "No se pudo obtener versión actual desde Flyway info" }
}

function Parse-Jdbc([string]$Url) {
  # jdbc:postgresql://host:port/dbName?...  → hashtable
  if ($Url -notmatch '^jdbc:postgresql://([^:/?]+):(\d+)/(\w+)') { throw "URL JDBC no válida: $Url" }
  return @{ host = $Matches[1]; port = [int]$Matches[2]; db = $Matches[3] }
}

function Run-UndoTeams([hashtable]$Cli, [string]$Url, [string]$User, [string]$Password, [int]$TargetVersion) {
  $args = @('undo',"-url=$Url","-user=$User","-password=$Password","-target=$TargetVersion","-outputType=json")
  if ($Cli.kind -eq 'cli') { & $Cli.cmd @args }
  else { & docker run --rm $Cli.image @args }
}

function Run-ManualUndo([string]$Url, [string]$User, [string]$Password, [string]$Schema, [int]$CurrentVersion, [int]$TargetVersion) {
  $repo = Get-RepoRoot
  $undoDir = Join-Path $repo 'src\main\resources\db\undo'
  if (-not (Test-Path $undoDir -PathType Container)) { throw "No existe directorio de undo: $undoDir" }
  $conn = Parse-Jdbc $Url
  $host = $conn.host; $port = $conn.port; $db = $conn.db
  $pgImage = 'postgres:16'

  for ($v = $CurrentVersion; $v -gt $TargetVersion; $v--) {
    $pattern = "U${v}__*.sql"
    $file = Get-ChildItem -Path $undoDir -Filter $pattern | Select-Object -First 1
    if (-not $file) { throw "Falta script undo para versión $v ($pattern)" }
    Write-Host "[Manual Undo] Ejecutando $($file.FullName)" -ForegroundColor Cyan
    $env:PGPASSWORD = $Password
    $localPath = $file.FullName
    # Usamos Docker psql para ejecutar el archivo
    $cmd = @('run','--rm','-e',"PGPASSWORD=$Password",'-v',"$(Get-Location):/workspace",'-w','/workspace',$pgImage,
      'psql','-h',$host,'-p',"$port",'-U',$User,'-d',$db,'-v',"ON_ERROR_STOP=1",'-f',($localPath.Replace((Get-Location).Path,'/workspace').Replace('\\','/')))
    & docker @cmd
  }
  Write-Host "Listo: Base revertida a $TargetVersion" -ForegroundColor Green
}

$pwd = Get-Password
$cli = Get-FlywayCLI -UseDocker:$UseDocker
$supportsUndo = Supports-Undo $cli
Write-Host "Flyway Teams Undo soportado: $supportsUndo" -ForegroundColor Yellow

$infoJson = Flyway-InfoJson $cli $Url $User $pwd
$current = Parse-CurrentVersion $infoJson
Write-Host "Versión actual: $current; Target: $TargetVersion" -ForegroundColor Cyan
if ($current -lt $TargetVersion) { throw "TargetVersion ($TargetVersion) es mayor que la versión actual ($current)" }

if ($supportsUndo) { Run-UndoTeams $cli $Url $User $pwd $TargetVersion }
else { Run-ManualUndo $Url $User $pwd $Schema $current $TargetVersion }