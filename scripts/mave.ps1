# Configura JAVA_HOME y PATH para usar Java 17
# Ahora soporta configuración persistente a nivel de USUARIO y SISTEMA.
# Nota: para escribir variables de entorno de SISTEMA (Machine) se requiere PowerShell como Administrador.

$ErrorActionPreference = 'Stop'

# Utilidad: normaliza y deduplica entradas de PATH
function Normalize-PathEntries([string[]]$entries) {
  $clean = @()
  foreach ($e in $entries) {
    if ($e -and $e.Trim().Length -gt 0) {
      $t = $e.Trim()
      if (-not ($clean | Where-Object { $_.Trim().ToLower() -eq $t.ToLower() })) {
        $clean += $t
      }
    }
  }
  return $clean
}

# Localiza un JDK 17 instalado (prioriza instalaciones de sistema para permanencia entre usuarios)
$candidatos = @()
try { $dirs = Get-ChildItem 'C:\Program Files\Eclipse Adoptium\jdk-17*' -Directory -ErrorAction SilentlyContinue; if ($dirs) { $candidatos += ($dirs | ForEach-Object { $_.FullName }) } } catch {}
try { $dirs = Get-ChildItem 'C:\Program Files\Microsoft\jdk-17*' -Directory -ErrorAction SilentlyContinue; if ($dirs) { $candidatos += ($dirs | ForEach-Object { $_.FullName }) } } catch {}
try { $dirs = Get-ChildItem 'C:\Program Files\Zulu\zulu-17*' -Directory -ErrorAction SilentlyContinue; if ($dirs) { $candidatos += ($dirs | ForEach-Object { $_.FullName }) } } catch {}
try { $dirs = Get-ChildItem 'C:\Program Files\Amazon Corretto\jdk-17*' -Directory -ErrorAction SilentlyContinue; if ($dirs) { $candidatos += ($dirs | ForEach-Object { $_.FullName }) } } catch {}
$candidatos += 'C:\Program Files\Java\jdk-17'
$candidatos += Join-Path $env:USERPROFILE 'scoop\apps\temurin17-jdk\current'  # fallback per-usuario

$jdkHome = $null
foreach ($p in $candidatos) {
  if (Test-Path (Join-Path $p 'bin\java.exe')) { $jdkHome = $p; break }
}

if (-not $jdkHome) {
  Write-Host 'No se encontró JDK 17. Instálalo con: scoop bucket add java; scoop install temurin17-jdk' -ForegroundColor Yellow
  exit 1
}

# Determina si el JDK es de sistema (Program Files) o per-usuario
$isSystemJdk = $jdkHome -notlike (Join-Path $env:USERPROFILE '*')

# Persistir JAVA_HOME a nivel SISTEMA si es JDK de sistema
if ($isSystemJdk) {
  try {
    [Environment]::SetEnvironmentVariable('JAVA_HOME', $jdkHome, 'Machine')
  } catch {
    Write-Host 'Aviso: no se pudo escribir JAVA_HOME (Machine). Ejecuta PowerShell como Administrador.' -ForegroundColor Yellow
  }
}

# Persistir JAVA_HOME (Usuario) siempre
[Environment]::SetEnvironmentVariable('JAVA_HOME', $jdkHome, 'User')

##########################
# Actualizar PATH de SISTEMA (si JDK es de sistema)
##########################
if ($isSystemJdk) {
  $machinePathRaw = [Environment]::GetEnvironmentVariable('Path','Machine')
  $machineEntries = @()
  if ($machinePathRaw) { $machineEntries = $machinePathRaw -split ';' }
  $machineEntries = Normalize-PathEntries $machineEntries

  # Remover entradas conflictivas (JRE shim y JDK viejos)
  $removeIfContains = @(
    'Common Files\Oracle\Java\javapath',
    '\\jdk-11',
    '\\jdk-10',
    '\\jdk-1.8',
    '\\jdk-1.7'
  )
  $machineEntries = $machineEntries | Where-Object {
    $keep = $true
    foreach ($pat in $removeIfContains) {
      if ($_.ToLower().Contains($pat.ToLower())) { $keep = $false; break }
    }
    $keep
  }

  # Anteponer JDK 17 bin
  $desiredMachine = @()
  $desiredMachine += (Join-Path $jdkHome 'bin')
  foreach ($e in $desiredMachine) {
    if (Test-Path $e) { $machineEntries = $machineEntries | Where-Object { $_.Trim().ToLower() -ne $e.Trim().ToLower() } }
  }
  $newMachinePath = ($desiredMachine + $machineEntries) -join ';'
  try {
    [Environment]::SetEnvironmentVariable('Path', $newMachinePath, 'Machine')
  } catch {
    Write-Host 'Aviso: no se pudo escribir PATH (Machine). Ejecuta PowerShell como Administrador.' -ForegroundColor Yellow
  }
}

##########################
# Actualizar PATH de USUARIO
##########################
$userPathRaw = [Environment]::GetEnvironmentVariable('Path','User')
$userPathEntries = @()
if ($userPathRaw) { $userPathEntries = $userPathRaw -split ';' }
$userPathEntries = Normalize-PathEntries $userPathEntries

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

# Entradas deseadas (al frente del PATH de usuario)
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
if ($isSystemJdk -and $newMachinePath) {
  # Sesión actual: PATH de máquina + usuario
  $env:Path = $newMachinePath + ';' + $newUserPath
} else {
  $env:Path = $newUserPath
}

Write-Host ("JAVA_HOME (Machine) " + ($(if ($isSystemJdk) { 'actualizado' } else { 'no modificado (JDK per-usuario)' })))
Write-Host "JAVA_HOME (User) establecido: $jdkHome"
Write-Host "PATH (User) actualizado. Prioridad: $($desired -join ', ')"
if (-not $isSystemJdk) {
  Write-Host "Para que sea permanente entre usuarios, instala un JDK 17 en 'C:\\Program Files' (p.ej. con: winget install -e --id EclipseAdoptium.Temurin.17.JDK) y vuelve a ejecutar este script como Administrador." -ForegroundColor Yellow
}

# Notificar cambio de entorno al sistema
try {
  Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class EnvBroadcast {
  [DllImport("user32.dll", SetLastError=true, CharSet=CharSet.Auto)]
  public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, IntPtr wParam, string lParam, uint fuFlags, uint uTimeout, out IntPtr lpdwResult);
}
'@ -ErrorAction SilentlyContinue
  [IntPtr]$result = [IntPtr]::Zero
  [EnvBroadcast]::SendMessageTimeout([IntPtr]0xffff, 0x1A, [IntPtr]0, "Environment", 0, 5000, [ref]$result) | Out-Null
} catch {}

Write-Host "Cierra y vuelve a abrir tus terminales/IDE; para apps ya abiertas puede requerirse cerrar sesión o reiniciar."

Write-Host "`nVerificación:" -ForegroundColor Cyan
java -version
javac -version
mvn -v