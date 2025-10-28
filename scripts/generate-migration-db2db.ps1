Param(
    [Parameter(Mandatory = $true)][string]$Description,
    # Origen (desarrollo)
    [string]$SrcHost = "127.0.0.1",
    [int]$SrcPort = 5432,
    [string]$SrcDb = "sasdatqbox",
    [string]$SrcUser = "sas_user",
    [string]$SrcPassword = "",
    # Destino (contenedores / HA)
    [string]$DstHost = "patroni-master",
    [int]$DstPort = 5432,
    [string]$DstDb = "sasdatqbox",
    [string]$DstUser = "sas_user",
    [string]$DstPassword = "",
    # Opciones
    [string]$Schema = "pos",
    [string]$OutputDir = "src/main/resources/db/migration",
    [switch]$NoDocker,
    [string]$DockerNetwork = "",
    [ValidateSet('liquibase','pgdump')][string]$Mode = 'pgdump',
    [switch]$Test
)

$ErrorActionPreference = 'Stop'

function Run-Maven([string[]]$ArgsArray) {
    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    # Solo se usa en modo Docker (para no requerir CLI local)

    $pwd = (Resolve-Path $repoRoot).Path
    $cmd = @('docker','run','--rm','-v',"$($pwd):/workspace",'-w','/workspace')
    if ($DockerNetwork -and $DockerNetwork.Trim().Length -gt 0) {
        $cmd += @('--network', $DockerNetwork)
    }
    $cmd += @('maven:3-eclipse-temurin-17','mvn','-q','-DskipTests')
    $cmd += $ArgsArray
    & $cmd
}

$LbVersion = '4.27.0'
function Ensure-LiquibaseCLI([string]$Version = $LbVersion) {
    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $toolsDir = Join-Path $repoRoot 'target/tools'
    if (-not (Test-Path $toolsDir)) { New-Item -ItemType Directory -Path $toolsDir -Force | Out-Null }
    $lbDir = Join-Path $toolsDir "liquibase-$Version"
    $lbExe = Join-Path $lbDir 'liquibase.bat'
    if (-not (Test-Path $lbExe)) {
        $zipUrl = "https://github.com/liquibase/liquibase/releases/download/v$Version/liquibase-$Version.zip"
        $zipPath = Join-Path $toolsDir "liquibase-$Version.zip"
        Write-Host "Descargando Liquibase CLI $Version..." -ForegroundColor Cyan
        Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing
        Expand-Archive -Path $zipPath -DestinationPath $lbDir -Force
    }
    $libDir = Join-Path $lbDir 'lib'
    if (-not (Test-Path $libDir)) { New-Item -ItemType Directory -Path $libDir -Force | Out-Null }
    $pgJar = Get-ChildItem -Path $libDir -Filter 'postgresql-*.jar' -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $pgJar) {
        $m2Jar = Join-Path $env:USERPROFILE ".m2\repository\org\postgresql\postgresql\42.6.0\postgresql-42.6.0.jar"
        if (Test-Path $m2Jar) { Copy-Item $m2Jar (Join-Path $libDir 'postgresql-42.6.0.jar') -Force }
        else {
            $pgUrl = 'https://repo1.maven.org/maven2/org/postgresql/postgresql/42.6.0/postgresql-42.6.0.jar'
            Invoke-WebRequest -Uri $pgUrl -OutFile (Join-Path $libDir 'postgresql-42.6.0.jar') -UseBasicParsing
        }
    }
    $script:LiquibaseExe = $lbExe
    $script:LiquibaseClasspath = $libDir
}

function Run-LiquibaseCLI([string[]]$ArgsArray) {
    if (-not $script:LiquibaseExe) { Ensure-LiquibaseCLI }
    & $script:LiquibaseExe @ArgsArray
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$workDir = Join-Path $repoRoot 'target/liquibase'
if (-not (Test-Path -Path $workDir)) { New-Item -ItemType Directory -Path $workDir -Force | Out-Null }

# Herramientas para pg_dump/apgdiff
$dumpsDir = Join-Path $repoRoot 'target/dumps'
if (-not (Test-Path -Path $dumpsDir)) { New-Item -ItemType Directory -Path $dumpsDir -Force | Out-Null }

function Get-DockerHost([string]$DbHost) {
    if ($DbHost -eq '127.0.0.1' -or $DbHost -eq 'localhost') { return 'host.docker.internal' }
    return $DbHost
}

function Ensure-PgDumpLocal() {
    $toolsDir = Join-Path $repoRoot 'target/tools'
    if (-not (Test-Path $toolsDir)) { New-Item -ItemType Directory -Path $toolsDir -Force | Out-Null }
    $pgDir = Join-Path $toolsDir 'pg-win64-16.3'
    $pgDumpExe = Join-Path $pgDir 'bin/pg_dump.exe'
    if (-not (Test-Path $pgDumpExe)) {
        $zipUrl = 'https://get.enterprisedb.com/postgresql/postgresql-16.3-1-windows-x64-binaries.zip'
        $zipPath = Join-Path $toolsDir 'pg-win64-16.3.zip'
        Write-Host "Descargando pg_dump para Windows..." -ForegroundColor Cyan
        Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing
        Expand-Archive -Path $zipPath -DestinationPath $pgDir -Force
    }
    $script:PgDumpExe = $pgDumpExe
}

function Run-PgDump([string]$DbHost,[int]$Port,[string]$Db,[string]$User,[string]$Password,[string]$Schema,[string]$OutFile) {
    if (-not $script:PgDumpExe) { Ensure-PgDumpLocal }
    $env:PGPASSWORD = $Password
    & $script:PgDumpExe -h $DbHost -p $Port -U $User -d $Db --schema=$Schema --no-owner --no-privileges --schema-only --file "$OutFile"
}

function Ensure-ApgDiffJar() {
    $toolsDir = Join-Path $repoRoot 'target/tools'
    if (-not (Test-Path $toolsDir)) { New-Item -ItemType Directory -Path $toolsDir -Force | Out-Null }
    $script:ApgDiffJar = Join-Path $toolsDir 'apgdiff.jar'
    if (-not (Test-Path $script:ApgDiffJar)) {
        $url = 'https://github.com/fordfrog/apgdiff/releases/download/2.6.1/apgdiff-2.6.1.jar'
        Invoke-WebRequest -Uri $url -OutFile $script:ApgDiffJar -UseBasicParsing
    }
}

function Run-ApgDiff([string]$OldFile,[string]$NewFile,[string]$OutFile) {
    Ensure-ApgDiffJar
    $pwd = (Resolve-Path $repoRoot).Path
    $cmd = @('docker','run','--rm','-v',"$($pwd):/workspace",'-w','/workspace')
    if ($DockerNetwork -and $DockerNetwork.Trim().Length -gt 0) { $cmd += @('--network', $DockerNetwork) }
    $inner = "java -jar /workspace/target/tools/apgdiff.jar $OldFile $NewFile > $OutFile"
    $cmd += @('maven:3-eclipse-temurin-17','sh','-lc',$inner)
    & $cmd
}

function Filter-PgDiffSQL([string]$sql) {
    $lines = $sql -split "`r?`n"
    $filtered = @()
    foreach ($line in $lines) {
        $trim = $line.Trim()
        if (-not $trim) { continue }
        if ($trim -match '(?i)^SET\s+') { continue }
        if ($trim -match '(?i)OWNER\s+TO') { continue }
        if ($trim -match '(?i)^COMMENT\s+ON\s+') { continue }
        $filtered += $line
    }
    return ($filtered -join [Environment]::NewLine)
}

$changeLogYaml = Join-Path $workDir 'diff-db.yml'
$generatedSql  = Join-Path $workDir 'diff-db.sql'
${pgDiffOut}    = Join-Path $workDir 'dbdiff.sql'

# Construcción de URIs JDBC
$srcJdbc = "jdbc:postgresql://$($SrcHost):$($SrcPort)/$($SrcDb)"
$dstJdbc = "jdbc:postgresql://$($DstHost):$($DstPort)/$($DstDb)"

Write-Host "[1/3] Generando diferencias de esquema (DB→DB)..." -ForegroundColor Cyan
$usedCLI = $false
if ($Mode -eq 'pgdump') {
    # Volcar esquemas y calcular diferencias con apgdiff (conversión: destino -> origen)
    $srcDump = (Join-Path $dumpsDir 'src-pos.sql')
    $dstDump = (Join-Path $dumpsDir 'dst-pos.sql')
    Run-PgDump -DbHost $SrcHost -Port $SrcPort -Db $SrcDb -User $SrcUser -Password $SrcPassword -Schema $Schema -OutFile $srcDump
    Run-PgDump -DbHost $DstHost -Port $DstPort -Db $DstDb -User $DstUser -Password $DstPassword -Schema $Schema -OutFile $dstDump
    Write-Host "Dump origen: $srcDump" -ForegroundColor Green
    Write-Host "Dump destino: $dstDump" -ForegroundColor Green
} else {
    Write-Host "Usando Liquibase diff-changelog..." -ForegroundColor Cyan
    if ($NoDocker) {
        $usedCLI = $true
        $diffArgsCli = @(
            "--classpath=$script:LiquibaseClasspath",
            "--reference-url=$srcJdbc",
            "--reference-username=$SrcUser",
            "--reference-password=$SrcPassword",
            "--url=$dstJdbc",
            "--username=$DstUser",
            "--password=$DstPassword",
            "--default-schema-name=$Schema",
            "--reference-default-schema-name=$Schema",
            "--schemas=$Schema",
            "--changelog-file=$changeLogYaml",
            'diff-changelog'
        )
        Run-LiquibaseCLI $diffArgsCli
    } else {
        $diffArgs = @(
            'org.liquibase:liquibase-maven-plugin:4.27.0:diff',
            "-Dliquibase.referenceUrl=$srcJdbc",
            "-Dliquibase.referenceUsername=$SrcUser",
            "-Dliquibase.referencePassword=$SrcPassword",
            "-Dliquibase.url=$dstJdbc",
            "-Dliquibase.username=$DstUser",
            "-Dliquibase.password=$DstPassword",
            "-Dliquibase.defaultSchemaName=$Schema",
            "-Dliquibase.referenceDefaultSchemaName=$Schema",
            "-Dliquibase.schemas=$Schema",
            "-Dliquibase.diffChangeLogFile=$changeLogYaml",
            "-Dliquibase.changeLogFile=$changeLogYaml"
        )
        Run-Maven $diffArgs
    }
}

Write-Host "[2/3] Renderizando SQL listo para Flyway..." -ForegroundColor Cyan
if ($Mode -eq 'pgdump') {
    Write-Host "Saltando render de SQL automático; revisa los dumps generados en $dumpsDir." -ForegroundColor Yellow
    $sqlContent = ""
} else {
    if ($NoDocker) {
        if (-not (Test-Path -Path $changeLogYaml)) {
            Write-Host "No hay diferencias (no se produjo changelog)." -ForegroundColor Yellow
            return $null
        }
        $sqlArgsCli = @(
            "--classpath=$script:LiquibaseClasspath",
            "--changelog-file=target/liquibase/diff-db.yml",
            "--default-schema-name=$Schema",
            "--url=$dstJdbc",
            "--username=$DstUser",
            "--password=$DstPassword",
            'update-sql',
            "--output-file=$generatedSql"
        )
        Run-LiquibaseCLI $sqlArgsCli
    } else {
        $sqlArgs = @(
            'org.liquibase:liquibase-maven-plugin:4.27.0:updateSQL',
            "-Dliquibase.changeLogFile=$changeLogYaml",
            "-Dliquibase.outputFile=$generatedSql",
            "-Dliquibase.defaultSchemaName=$Schema",
            "-Dliquibase.url=$dstJdbc",
            "-Dliquibase.username=$DstUser",
            "-Dliquibase.password=$DstPassword"
        )
        Run-Maven $sqlArgs
    }
    if (-not (Test-Path -Path $generatedSql)) { throw "No se generó el archivo SQL esperado: $generatedSql" }
    $sqlContent = Get-Content -Path $generatedSql -Raw
    function Filter-LiquibaseSQL([string]$sql) {
        $lines = $sql -split "`r?`n"
        $filtered = @()
        foreach ($line in $lines) {
            $trim = $line.Trim()
            if (-not $trim) { continue }
            if ($trim -match '(?i)databasechangeloglock' -or $trim -match '(?i)databasechangelog') { continue }
            if ($trim -match '(?i)^--\s*(Create|Initialize|Lock|Release)\s*(Database\s*Lock|Lock\s*Database)') { continue }
            if ($trim -match '(?i)^SET\s+SEARCH_PATH') { continue }
            $filtered += $line
        }
        return ($filtered -join [Environment]::NewLine)
    }
    $sqlContent = Filter-LiquibaseSQL $sqlContent
}

if ($Mode -ne 'pgdump') {
    if (-not $sqlContent.Trim()) {
        Write-Host "No hay diferencias entre origen y destino para el esquema '$Schema'." -ForegroundColor Yellow
        return $null
    }
}

# Crear el archivo de migración Flyway y anexar el SQL generado
$newMigrationScript = Join-Path $PSScriptRoot 'new-migration.ps1'
if (-not (Test-Path -Path $newMigrationScript)) { throw "No se encontró scripts/new-migration.ps1" }
$migrationPath = & $newMigrationScript -Description $Description -Dir $OutputDir -Schema $Schema -Test:$Test

if ($Mode -eq 'pgdump') {
    Write-Host "Modo pgdump: se generaron archivos SQL de objetos. Usa estos dumps para construir migraciones." -ForegroundColor Green
    return @{
        SrcDump = (Join-Path $dumpsDir 'src-pos.sql')
        DstDump = (Join-Path $dumpsDir 'dst-pos.sql')
    }
}

$timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz'
$header = @(
    "-- Generated by Liquibase (DB→DB diff) on $timestamp",
    "-- Source: $srcJdbc (user=$SrcUser, schema=$Schema)",
    "-- Target: $dstJdbc (user=$DstUser, schema=$Schema)",
    "-- Nota: Flyway ejecuta cada migración en una transacción (no uses BEGIN/COMMIT)",
    "SET LOCAL search_path TO $Schema;",
    ""
) -join [Environment]::NewLine

Set-Content -Path $migrationPath -Value ($header + $sqlContent) -Encoding UTF8

Write-Host "Listo: $migrationPath" -ForegroundColor Green
return $migrationPath
# Modo visualización: redirigir salida a migration-test
if ($Test) { $OutputDir = 'src/main/resources/db/migration-test' }