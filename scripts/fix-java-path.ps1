Param(
  [switch]$MachineOnly
)

function Get-Jdk17Home {
  if (Test-Path 'C:\Program Files\Java\jdk-17') { return 'C:\Program Files\Java\jdk-17' }

  $adoptiumRoot = 'C:\Program Files\Eclipse Adoptium'
  if (Test-Path $adoptiumRoot) {
    $dirs = Get-ChildItem -Directory -Path $adoptiumRoot -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'jdk-17*' }
    if ($dirs -and $dirs.Count -gt 0) { return ($dirs | Sort-Object Name -Descending | Select-Object -First 1).FullName }
  }

  if (Test-Path 'C:\Users\Dell\scoop\apps\temurin17-jdk\current') { return 'C:\Users\Dell\scoop\apps\temurin17-jdk\current' }

  throw 'No encuentro una instalación de JDK 17'
}

function Filter-PathEntries([string[]]$entries) {
  $entries | Where-Object {
    $_ -and $_.Trim() -ne '' -and
    -not ($_.ToLower().Contains('\jdk-11')) -and
    -not ($_.ToLower().Contains('temurin11-jdk')) -and
    -not ($_.ToLower().Contains('common files\oracle\java\javapath')) -and
    -not ($_.ToLower().Contains('debugcommand='))
  }
}

function Dedup-Entries([string[]]$entries) {
  $seen = @{}
  $out = New-Object System.Collections.Generic.List[string]
  foreach ($e in $entries) {
    $k = $e.Trim().ToLower()
    if ($k -and -not $seen.ContainsKey($k)) { $seen[$k] = $true; $out.Add($e) }
  }
  return $out.ToArray()
}

function Set-PathAndJavaHome([string]$jdkHome,[ValidateSet('Machine','User')]$scope) {
  $jdkBin = Join-Path $jdkHome 'bin'
  $current = [Environment]::GetEnvironmentVariable('Path',$scope)
  $entries = Filter-PathEntries ($current -split ';')
  $entries = @($jdkBin) + ($entries | Where-Object { $_.Trim().ToLower() -ne $jdkBin.ToLower() })
  $entries = Dedup-Entries $entries
  [Environment]::SetEnvironmentVariable('Path', ($entries -join ';'), $scope)
  [Environment]::SetEnvironmentVariable('JAVA_HOME', $jdkHome, $scope)
}

function Broadcast-EnvChange {
  Add-Type -Namespace Win32 -Name NativeMethods -Member '[DllImport("user32.dll", SetLastError=true, CharSet=CharSet.Auto)]public static extern IntPtr SendMessageTimeout(IntPtr hWnd, int Msg, IntPtr wParam, string lParam, int fuFlags, int uTimeout, out IntPtr lpdwResult);'
  $HWND_BROADCAST=[IntPtr]0xffff; $WM_SETTINGCHANGE=0x1A; $result=[IntPtr]::Zero
  [Win32.NativeMethods]::SendMessageTimeout($HWND_BROADCAST,$WM_SETTINGCHANGE,[IntPtr]::Zero,'Environment',2,5000,[ref]$result) | Out-Null
}

try {
  $jdkHome = Get-Jdk17Home
} catch {
  Write-Error $_.Exception.Message
  exit 1
}

try {
  if ($MachineOnly) {
    Set-PathAndJavaHome -jdkHome $jdkHome -scope 'Machine'
  } else {
    try { Set-PathAndJavaHome -jdkHome $jdkHome -scope 'Machine' } catch { Write-Warning 'No se pudo escribir en PATH/JAVA_HOME (Machine). Ejecute como Administrador.' }
    Set-PathAndJavaHome -jdkHome $jdkHome -scope 'User'
  }
} catch {
  Write-Error $_.Exception.Message
}

Broadcast-EnvChange

# Establecer para la sesión actual, para demostrar inmediatamente que resuelve a 17
$env:JAVA_HOME = $jdkHome
$env:Path = (Join-Path $jdkHome 'bin') + ';' + [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')

Write-Host ('JAVA_HOME (User): ' + [Environment]::GetEnvironmentVariable('JAVA_HOME','User'))
Write-Host ('JAVA_HOME (Machine): ' + [Environment]::GetEnvironmentVariable('JAVA_HOME','Machine'))
Write-Host 'PATH (primeras 5 entradas):'
(($env:Path -split ';') | Select-Object -First 5) | ForEach-Object { Write-Host (' - ' + $_) }

# Verificación inmediata
& (Join-Path $jdkHome 'bin\java.exe') -version
& (Join-Path $jdkHome 'bin\javac.exe') -version
if (Get-Command mvn.exe -ErrorAction SilentlyContinue) {
  & mvn -v
} elseif (Get-Command mvn.cmd -ErrorAction SilentlyContinue) {
  & mvn -v
} else {
  Write-Host 'Maven no encontrado en PATH; esto no bloquea Java 17.'
}

Write-Host 'JAVA_HOME y PATH actualizados. Cierra y reabre terminal/IDE; reiniciar el PC asegura propagación.'