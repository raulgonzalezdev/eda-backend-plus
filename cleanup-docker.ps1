#requires -Version 5.1
[CmdletBinding()] param(
  [switch] $Preview,
  [switch] $Aggressive
)

function Exec {
  param([string] $cmd)
  Write-Host (">> " + $cmd) -ForegroundColor Cyan
  try {
    & cmd /c $cmd
  } catch {
    Write-Warning $_
  }
}

Write-Host "Docker cleanup helper" -ForegroundColor Green

# Verificación de Docker
try {
  & cmd /c "docker version" | Out-Null
} catch {
  Write-Error "Docker no disponible. Asegúrate de que el daemon esté corriendo."; exit 1
}

Write-Host "Estado inicial (docker system df):" -ForegroundColor Yellow
Exec "docker system df"

if ($Preview) {
  Write-Host "Previsualización de recursos huérfanos (no se elimina nada)" -ForegroundColor Yellow
  Exec "docker volume ls -f dangling=true"
  Exec "docker images -f dangling=true"
  Write-Host "Redes no usadas no tienen preview exacto; se listan todas:" -ForegroundColor Yellow
  Exec "docker network ls"
  Write-Host "Fin de preview." -ForegroundColor Yellow
  exit 0
}

# Limpiezas seguras (solo no referenciados/no usados)
Exec "docker volume prune -f"
if ($Aggressive) {
  # El modo agresivo elimina imágenes no usadas por NINGÚN contenedor (incluye las no dangling)
  Exec "docker image prune -a -f"
} else {
  Exec "docker image prune -f"
}
Exec "docker network prune -f"
Exec "docker builder prune -f"

Write-Host "Estado final (docker system df):" -ForegroundColor Yellow
Exec "docker system df"

Write-Host "Limpieza completada." -ForegroundColor Green