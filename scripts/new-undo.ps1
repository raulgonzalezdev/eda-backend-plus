param(
  [Parameter(Mandatory=$true)][int]$Version,
  [string]$Description,
  [string]$Schema = 'pos',
  [switch]$OpenFile
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-RepoRoot { (Get-Location).Path }
function Slugify([string]$s) {
  $s = $s.ToLower()
  $s = ($s -replace '[^a-z0-9]+','_')
  $s = ($s -replace '_+','_').Trim('_')
  if ([string]::IsNullOrEmpty($s)) { return "v$Version" } else { return $s }
}

$root = Get-RepoRoot
$migsDir = Join-Path $root 'src/main/resources/db/migration'
$undoDir = Join-Path $root 'src/main/resources/db/undo'
if (-not (Test-Path $undoDir -PathType Container)) { $null = New-Item -ItemType Directory -Path $undoDir }

if (-not $Description) {
  $pattern = "V${Version}__*.sql"
  $existing = Get-ChildItem -Path $migsDir -Filter $pattern | Select-Object -First 1
  if ($existing) {
    $desc = ($existing.BaseName -replace "^V${Version}__", '')
    $Description = $desc
  } else {
    $Description = "undo_for_V${Version}"
  }
}

$slug = Slugify $Description
$filename = "U${Version}__${slug}.sql"
$filePath = Join-Path $undoDir $filename

if (Test-Path $filePath) { Write-Host "Ya existe: $filePath" -ForegroundColor Yellow; exit 0 }

$timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz')
$header = @(
  "-- Undo Migration: $filename",
  "-- Pairs with: V${Version}__${slug}.sql (ajústalo si difiere)",
  "-- Created: $timestamp",
  "-- Schema: $Schema",
  "-- Nota: Flyway ejecuta cada undo en transacción (Teams); usa este archivo manualmente si no tienes Teams",
  "SET LOCAL search_path TO $Schema;",
  "",
  "-- Escribe aquí las sentencias que revierten V${Version}__${slug}.sql.",
  "-- Recomendaciones:",
  "-- - Revertir cambios de DDL en orden inverso (FKs → índices → constraints → columnas → tablas).",
  "-- - Si hubo cambios de datos, añade guardas para no perder información (backups temporales).",
  ""
) -join [Environment]::NewLine

Set-Content -Path $filePath -Value $header -Encoding UTF8
Write-Host "Creado: $filePath" -ForegroundColor Green
if ($OpenFile) { Invoke-Item $filePath }
return $filePath