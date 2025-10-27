Param(
    [Parameter(Mandatory = $true)][string]$Description,
    [string]$Dir = "src/main/resources/db/migration",
    [switch]$OpenFile
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
    return ([int]([array]::Max($versions)) + 1)
}

function To-Slug([string]$Text) {
    $slug = ($Text).ToLower()
    $slug = $slug -replace '[^a-z0-9]+', '_'
    $slug = $slug -replace '_+', '_'
    return $slug.Trim('_')
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
        "-- Schema: pos",
        "",
        "-- Añade tus sentencias SQL debajo. Ejemplos:",
        "-- CREATE TABLE pos.mi_tabla (...);",
        "-- CREATE INDEX IF NOT EXISTS idx_mi_tabla_col ON pos.mi_tabla(col);",
        ""
    ) -join [Environment]::NewLine

    Set-Content -Path $filePath -Value $header -Encoding UTF8
    Write-Host "Creado: $filePath" -ForegroundColor Green
}

if ($OpenFile) {
    Invoke-Item $filePath
}

return $filePath