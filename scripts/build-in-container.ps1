#requires -Version 5.1
[CmdletBinding()] param(
  [switch] $SkipTests,
  [switch] $CleanLocalM2,
  [switch] $ComposeUp,
  [string] $DockerImage = 'maven:3.9.9-eclipse-temurin-17',
  [string] $ProjectPath = '.'
)

function Exec {
  param([string] $cmd)
  Write-Host (">> " + $cmd) -ForegroundColor Cyan
  & cmd /c $cmd
  if ($LASTEXITCODE -ne 0) { throw "Fallo ejecutando: $cmd" }
}

Write-Host "Compilación en contenedor Maven (sin usar librerías locales)" -ForegroundColor Green

if (-not (Test-Path (Join-Path $ProjectPath 'pom.xml'))) {
  Write-Error "No se encontró pom.xml en '$ProjectPath'. Asegúrate de apuntar al proyecto correcto."; exit 1
}

# Opcional: limpiar repositorio local de Maven para liberar espacio en C:
if ($CleanLocalM2) {
  $m2 = Join-Path $env:USERPROFILE '.m2\repository'
  if (Test-Path $m2) {
    Write-Host "Eliminando repositorio Maven local: $m2" -ForegroundColor Yellow
    try { Remove-Item -LiteralPath $m2 -Recurse -Force -ErrorAction Stop } catch { Write-Warning $_ }
  } else {
    Write-Host "Repositorio Maven local no existe: $m2" -ForegroundColor Yellow
  }
}

$hostPath = (Resolve-Path $ProjectPath).Path
Write-Host "Usando ruta del proyecto: $hostPath" -ForegroundColor Yellow

# Construir con Maven dentro del contenedor
$skipFlag = if ($SkipTests) { '-DskipTests' } else { '' }
Exec "docker run --rm -v `"$hostPath`":/workspace -w /workspace $DockerImage mvn -B $skipFlag clean package"

# Reportar artefactos
if (Test-Path (Join-Path $hostPath 'target')) {
  $artifacts = Get-ChildItem (Join-Path $hostPath 'target') -Filter *.jar -Recurse -ErrorAction SilentlyContinue
  if ($artifacts.Count -gt 0) {
    Write-Host "Artefactos construidos:" -ForegroundColor Green
    $artifacts | ForEach-Object { Write-Host " - $_" }
  } else {
    Write-Warning "No se encontraron JARs en 'target'. Revisa el log de Maven."
  }
}

if ($ComposeUp) {
  Write-Host "Compilación OK; levantando contenedores con docker compose..." -ForegroundColor Yellow
  Exec "docker compose up -d"
}

Write-Host "Compilación en contenedor finalizada." -ForegroundColor Green