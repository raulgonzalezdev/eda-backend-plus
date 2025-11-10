#requires -Version 5.1
[CmdletBinding()] param(
  [int] $Days = 14,
  [switch] $Preview,
  [switch] $Aggressive,
  [switch] $DevCaches,
  [switch] $ComponentCleanup
)

function Test-IsAdmin {
  try {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  } catch { return $false }
}

function Format-Size([long] $bytes) {
  if ($bytes -ge 1GB) { '{0:N2} GB' -f ($bytes/1GB) }
  elseif ($bytes -ge 1MB) { '{0:N2} MB' -f ($bytes/1MB) }
  else { '{0:N0} KB' -f [math]::Max(1,($bytes/1KB)) }
}

function Get-DeletionCandidates {
  param([string] $Path, [int] $OlderThanDays, [switch] $IgnoreAge)
  if (-not (Test-Path $Path)) { return @() }
  $cutoff = (Get-Date).AddDays(-$OlderThanDays)
  try {
    $items = Get-ChildItem -LiteralPath $Path -Force -Recurse -ErrorAction SilentlyContinue
    if ($IgnoreAge) { return $items }
    else { return $items | Where-Object { $_.LastWriteTime -lt $cutoff } }
  } catch { return @() }
}

function Remove-ItemsSafe {
  param([System.Collections.IEnumerable] $Items)
  $size = 0L; $count = 0
  foreach ($i in $Items) {
    try {
      if ($i -is [System.IO.FileInfo]) { $size += $i.Length }
      Remove-Item -LiteralPath $i.FullName -Force -Recurse -ErrorAction SilentlyContinue
      $count++
    } catch { }
  }
  return [PSCustomObject]@{ Count = $count; Size = $size }
}

function Show-DriveUsage([string] $Drive = 'C') {
  try {
    $d = Get-PSDrive -Name $Drive
    $totalBytes = ($d.Used + $d.Free)
    Write-Host ("Unidad {0}: Total {1}, Libre {2}" -f $Drive, (Format-Size $totalBytes), (Format-Size $d.Free)) -ForegroundColor Yellow
  } catch { }
}

Write-Host "Limpieza segura de Windows (AppData y temporales)" -ForegroundColor Green
Show-DriveUsage 'C'
$isAdmin = Test-IsAdmin
if (-not $isAdmin -and ($ComponentCleanup -or $Aggressive)) {
  Write-Warning "Algunas tareas agresivas/OS requieren admin; se omitirán sin elevación."
}

$targets = @()

# Temp del usuario
$targets += [PSCustomObject]@{ Path = "$env:TEMP"; IgnoreAge = $false }
$targets += [PSCustomObject]@{ Path = "$env:LOCALAPPDATA\Temp"; IgnoreAge = $false }
$targets += [PSCustomObject]@{ Path = "$env:LOCALAPPDATA\Microsoft\Windows\INetCache"; IgnoreAge = $false }
$targets += [PSCustomObject]@{ Path = "$env:USERPROFILE\AppData\Local\CrashDumps"; IgnoreAge = $false }
$targets += [PSCustomObject]@{ Path = "$env:LOCALAPPDATA\Packages"; IgnoreAge = $false }

# Cachés de dev (opcionales)
if ($DevCaches) {
  $targets += [PSCustomObject]@{ Path = "$env:USERPROFILE\.m2\repository"; IgnoreAge = $false }
  $targets += [PSCustomObject]@{ Path = "$env:USERPROFILE\.gradle\caches"; IgnoreAge = $false }
  $targets += [PSCustomObject]@{ Path = "$env:LOCALAPPDATA\npm-cache"; IgnoreAge = $false }
  $targets += [PSCustomObject]@{ Path = "$env:LOCALAPPDATA\pip\Cache"; IgnoreAge = $false }
  $targets += [PSCustomObject]@{ Path = "$env:LOCALAPPDATA\Yarn\Cache"; IgnoreAge = $false }
}

# Tareas del sistema (solo admin)
if ($isAdmin) {
  $targets += [PSCustomObject]@{ Path = "C:\Windows\Temp"; IgnoreAge = $false }
  if ($Aggressive) {
    # SoftwareDistribution\Download suele ser seguro eliminarlo (descargas de updates)
    $targets += [PSCustomObject]@{ Path = "C:\Windows\SoftwareDistribution\Download"; IgnoreAge = $true }
  }
}

$report = @()
foreach ($t in $targets) {
  $cand = Get-DeletionCandidates -Path $t.Path -OlderThanDays $Days -IgnoreAge:$t.IgnoreAge
  $size = ($cand | Where-Object { $_ -is [System.IO.FileInfo] } | Measure-Object -Property Length -Sum).Sum
  $report += [PSCustomObject]@{ Path = $t.Path; Count = ($cand.Count); Size = (Format-Size ([long]($size))) }
}

Write-Host "Resumen de candidatos (mayores a $Days días, salvo IgnoreAge):" -ForegroundColor Cyan
$report | Where-Object { $_.Count -gt 0 } | Format-Table -AutoSize

if ($Preview) {
  Write-Host "Preview activo: no se eliminará nada." -ForegroundColor Yellow
  Show-DriveUsage 'C'
  exit 0
}

Write-Host "Eliminando candidatos..." -ForegroundColor Cyan
$totalRemoved = 0L; $totalCount = 0
foreach ($t in $targets) {
  $cand = Get-DeletionCandidates -Path $t.Path -OlderThanDays $Days -IgnoreAge:$t.IgnoreAge
  $res = Remove-ItemsSafe -Items $cand
  $totalRemoved += $res.Size
  $totalCount += $res.Count
  if ($res.Count -gt 0) {
    Write-Host ("- ${t.Path}: {0} elementos, {1} liberados" -f $res.Count, (Format-Size $res.Size))
  }
}

# Vaciar papelera
try { Clear-RecycleBin -Force -ErrorAction SilentlyContinue } catch { }

# Limpieza de componentes de Windows (WinSxS) - opcional
if ($ComponentCleanup -and $isAdmin) {
  Write-Host "Ejecutando DISM StartComponentCleanup (puede tardar)..." -ForegroundColor Yellow
  try { & dism.exe /Online /Cleanup-Image /StartComponentCleanup | Out-Null } catch { Write-Warning $_ }
}

Write-Host ("Total aproximado liberado: {0}" -f (Format-Size $totalRemoved)) -ForegroundColor Green
Show-DriveUsage 'C'
Write-Host "Limpieza segura completada." -ForegroundColor Green