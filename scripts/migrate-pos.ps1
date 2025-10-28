Param(
  [switch]$Test
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Get-RepoRoot { (Get-Location).Path }

$root = Get-RepoRoot
$subPath = 'src\main\resources\db\migration'
if ($Test) { $subPath = 'src\main\resources\db\migration-test' }
$migDir = Join-Path $root $subPath
if (-not (Test-Path $migDir -PathType Container)) { $null = New-Item -ItemType Directory -Path $migDir }

$bashCmd = Get-Command bash -ErrorAction SilentlyContinue
if (-not $bashCmd) { Write-Warning "bash no está disponible; instala Git Bash o WSL. Se omite generación."; return }

Write-Host "[POS] Orquestando exportación DEV/PRO y generación de diffs en: $migDir" -ForegroundColor Cyan

# Usar el pipeline original basado en Docker/psql:
#   scripts/build-migrations.sh -> exporta DDL de DEV y PRO y convierte diffs
$profileArg = if ($Test) { 'test' } else { '' }
Push-Location $root
try {
  $cmd = "./scripts/build-migrations.sh $profileArg"
  & bash -c $cmd
} finally { Pop-Location }

# Listado final de migraciones (el build ya lista, pero mostramos ruta consolidada)
Write-Host "[List] Archivos en ${migDir}:" -ForegroundColor Cyan
Get-ChildItem -Path $migDir -Filter 'V*__*.sql' | Sort-Object Name | ForEach-Object { Write-Host $_.Name }

Write-Host "Hecho. Valida/aplica con scripts/flyway-runner.ps1 $(if ($Test){'-Test '})-Only <db-name> (configura scripts/flyway/params/*.json)." -ForegroundColor Green