# Configura JAVA_HOME y PATH para usar Java 17 (Temurin via Scoop)
# Persistente para el usuario actual y aplica también en la sesión actual.

$ErrorActionPreference = 'Stop'

# Localiza un JDK 17 instalado
$candidatos = @()
$candidatos += Join-Path $env:USERPROFILE 'scoop\apps\temurin17-jdk\current'
$candidatos += 'C:\Program Files\Java\jdk-17'
try { $dirs = Get-ChildItem 'C:\Program Files\Eclipse Adoptium\jdk-17*' -Directory -ErrorAction SilentlyContinue; if ($dirs) { $candidatos += ($dirs | ForEach-Object { $_.FullName }) } } catch {}
try { $dirs = Get-ChildItem 'C:\Program Files\Microsoft\jdk-17*' -Directory -ErrorAction SilentlyContinue; if ($dirs) { $candidatos += ($dirs | ForEach-Object { $_.FullName }) } } catch {}
try { $dirs = Get-ChildItem 'C:\Program Files\Zulu\zulu-17*' -Directory -ErrorAction SilentlyContinue; if ($dirs) { $candidatos += ($dirs | ForEach-Object { $_.FullName }) } } catch {}
try { $dirs = Get-ChildItem 'C:\Program Files\Amazon Corretto\jdk-17*' -Directory -ErrorAction SilentlyContinue; if ($dirs) { $candidatos += ($dirs | ForEach-Object { $_.FullName }) } } catch {}

$jdkHome = $null
foreach ($p in $candidatos) {
  if (Test-Path (Join-Path $p 'bin\java.exe')) { $jdkHome = $p; break }
}

if (-not $jdkHome) {
  Write-Host 'No se encontró JDK 17. Instálalo con: scoop bucket add java; scoop install temurin17-jdk' -ForegroundColor Yellow
  exit 1
}

# Persistir JAVA_HOME (Usuario)
[Environment]::SetEnvironmentVariable('JAVA_HOME', $jdkHome, 'User')

# Construir nuevo PATH de usuario
$userPathRaw = [Environment]::GetEnvironmentVariable('Path','User')
$userPathEntries = @()
if ($userPathRaw) { $userPathEntries = $userPathRaw -split ';' }
$userPathEntries = $userPathEntries | Where-Object { $_ -and $_.Trim().Length -gt 0 }

# Remover entradas conflictivas (JRE shim y JDK viejos)
$removeIfContains = @(
  'Common Files\Oracle\Java\javapath',
  '\\jdk-11',
  '\\jdk-10',
  '\\jdk-1.8',
  '\\jdk-1.7'
)
$userPathEntries = $userPathEntries | Where-Object {
  $keep = $true
  foreach ($pat in $removeIfContains) {
    if ($_.ToLower().Contains($pat.ToLower())) { $keep = $false; break }
  }
  $keep
}

# Entradas deseadas (al frente del PATH)
$desired = @()
$desired += (Join-Path $jdkHome 'bin')
$desired += (Join-Path $env:USERPROFILE 'scoop\apps\maven\current\bin')
$desired += (Join-Path $env:USERPROFILE 'scoop\shims')

# Deduplicar y anteponer deseadas
foreach ($e in $desired) {
  if (Test-Path $e) {
    $userPathEntries = $userPathEntries | Where-Object { $_.Trim().ToLower() -ne $e.Trim().ToLower() }
  }
}
$newUserPath = ($desired + $userPathEntries) -join ';'
[Environment]::SetEnvironmentVariable('Path', $newUserPath, 'User')

# Reflejar en la sesión actual
$env:JAVA_HOME = $jdkHome
$env:Path = $newUserPath

Write-Host "JAVA_HOME (User) establecido: $jdkHome"
Write-Host "PATH (User) actualizado. Prioridad: $($desired -join ', ')"
Write-Host "Cierra y vuelve a abrir tus terminales/IDE para que tomen los cambios."

Write-Host "`nVerificación:" -ForegroundColor Cyan
java -version
javac -version
mvn -v