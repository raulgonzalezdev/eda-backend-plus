Param(
    [Parameter(Mandatory = $true)][string]$Description,
    [string]$Dir = "src/main/resources/db/migration",
    [string]$Schema = "pos",
    [switch]$OpenFile,
    [switch]$Test
)

function Get-NextVersion([string]$MigrationDir) {
    if (-not (Test-Path -Path $MigrationDir)) {
        return 1
    }
    $files = Get-ChildItem -Path $MigrationDir -Filter 'V*__*.sql' -ErrorAction SilentlyContinue
    if (-not $files -or $files.Count -eq 0) { return 1 }
    $versions = @()
    foreach ($f in $files) {
        if ($f.BaseName -match '^V(\d+)__') { $versions += [int]$Matches[1] }
    }
    if ($versions.Count -eq 0) { return 1 }
    $max = ($versions | Measure-Object -Maximum).Maximum
    return ($max + 1)
}

function To-Slug([string]$Text) {
    $slug = ($Text).ToLower()
    $slug = $slug -replace '[^a-z0-9]+', '_'
    $slug = $slug -replace '_+', '_'
    return $slug.Trim('_')
}

$ErrorActionPreference = 'Stop'

# Si se solicita modo visualización (-Test), redirigir a migration-test
if ($Test) {
    $Dir = "src/main/resources/db/migration-test"
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$migrationDir = Join-Path $repoRoot $Dir
if (-not (Test-Path -Path $migrationDir)) {
    New-Item -ItemType Directory -Path $migrationDir -Force | Out-Null
}

$version = Get-NextVersion -MigrationDir $migrationDir
$slug = To-Slug -Text $Description
$fileName = "V${version}__${slug}.sql"
$filePath = Join-Path $migrationDir $fileName

if (Test-Path -Path $filePath) {
    Write-Host "El archivo ya existe: $filePath" -ForegroundColor Yellow
} else {
$timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz'
$header = @(
        "-- Migration: $fileName",
        "-- Description: $Description",
        "-- Created: $timestamp",
        "-- Schema: $Schema",
        "-- Nota: Flyway ejecuta cada migración en una transacción (no uses BEGIN/COMMIT aquí)",
        "SET LOCAL search_path TO $Schema;",
        "",
        "-- Añade tus sentencias SQL debajo. Ejemplos:",
        "-- CREATE TABLE $Schema.mi_tabla (...);",
        "-- CREATE INDEX IF NOT EXISTS idx_mi_tabla_col ON $Schema.mi_tabla(col);",
        ""
    ) -join [Environment]::NewLine

    Set-Content -Path $filePath -Value $header -Encoding UTF8
    Write-Host "Creado: $filePath" -ForegroundColor Green
}

if ($OpenFile) {
    Invoke-Item $filePath
}

return $filePath