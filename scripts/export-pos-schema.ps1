Param(
    [Parameter(Mandatory=$true)][string]$DbContainerName,
    [Parameter(Mandatory=$true)][string]$DbName,
    [Parameter(Mandatory=$true)][string]$DbUser,
    [Parameter(Mandatory=$true)][string]$DbPassword,
    [string]$Schema = 'pos',
    [string]$OutputRoot = 'db'
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $repoRoot

function Invoke-DbQuery {
    param(
        [string]$Sql,
        [switch]$RawOutput
    )
    $escapedSql = $Sql.Replace('"','\"')
    $inner = "PGPASSWORD=\"$DbPassword\" psql -h localhost -p 5432 -U $DbUser -d $DbName -At -c \"$escapedSql\""
    $output = & 'docker' 'exec' $DbContainerName 'sh' '-lc' $inner
    if ($RawOutput) { return $output }
    else { return $output -split "`r?`n" | Where-Object { $_ -ne '' } }
}

function Ensure-Dir {
    param([string]$Path)
    $null = New-Item -ItemType Directory -Force -Path $Path
}

$schemaObjects = [ordered]@{
    TABLES = @()
    VIEWS   = @()
    FUNCTIONS = @()
    PROCEDURES = @()
}

# Discover objects
$schemaObjects.TABLES = Invoke-DbQuery "SELECT tablename FROM pg_tables WHERE schemaname='${Schema}' ORDER BY tablename;"
$schemaObjects.VIEWS  = Invoke-DbQuery "SELECT table_name FROM information_schema.views WHERE table_schema='${Schema}' ORDER BY table_name;"
$funcRows = Invoke-DbQuery "SELECT p.proname||'|'||pg_get_function_identity_arguments(p.oid) AS sig FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='${Schema}' AND p.prokind='f' ORDER BY p.proname, pg_get_function_identity_arguments(p.oid);"
$procRows = Invoke-DbQuery "SELECT p.proname||'|'||pg_get_function_identity_arguments(p.oid) AS sig FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='${Schema}' AND p.prokind='p' ORDER BY p.proname, pg_get_function_identity_arguments(p.oid);"
$schemaObjects.FUNCTIONS = $funcRows
$schemaObjects.PROCEDURES = $procRows

if ($schemaObjects.TABLES.Count -eq 0 -and $schemaObjects.VIEWS.Count -eq 0 -and $schemaObjects.FUNCTIONS.Count -eq 0 -and $schemaObjects.PROCEDURES.Count -eq 0) {
    Write-Host "No se encontraron objetos en el esquema '$Schema' de la BD '$DbName'."
    return
}

$root = Join-Path $repoRoot $OutputRoot

foreach ($t in $schemaObjects.TABLES) {
    $dir = Join-Path $root (Join-Path $Schema (Join-Path 'TABLES' $t))
    Ensure-Dir $dir
    $file = Join-Path $dir "$t.sql"

    $header = @(
        "-- Source: jdbc:postgresql://127.0.0.1:5432/$DbName",
        "-- Usuario: $DbUser",
        "-- Contenedor: $DbContainerName",
        "SET LOCAL search_path TO $Schema;",
        ""
    )
    Set-Content -Path $file -Value ($header -join "`n")

    $createSql = @"
WITH cols AS (
  SELECT '  '||quote_ident(c.column_name)||' '||format_type(a.atttypid,a.atttypmod)
         || CASE WHEN c.is_identity='YES' THEN ' GENERATED '||c.identity_generation||' AS IDENTITY' ELSE '' END
         || CASE WHEN c.is_nullable='NO' THEN ' NOT NULL' ELSE '' END
         || CASE WHEN c.column_default IS NOT NULL AND c.is_identity<>'YES' THEN ' DEFAULT '||c.column_default ELSE '' END
         || CASE WHEN row_number() OVER (ORDER BY c.ordinal_position) < (SELECT count(*) FROM information_schema.columns WHERE table_schema='${Schema}' AND table_name='${t}') THEN ',' ELSE '' END AS coldef
  FROM information_schema.columns c
  JOIN pg_attribute a ON a.attrelid = '"${Schema}"."${t}"'::regclass AND a.attname=c.column_name
  WHERE c.table_schema='${Schema}' AND c.table_name='${t}'
  ORDER BY c.ordinal_position
)
SELECT 'CREATE TABLE '||quote_ident('${Schema}')||'.'||quote_ident('${t}')||E' (\n'
       || string_agg(coldef, E'\n') || E'\n);'
FROM cols;
"@
    Invoke-DbQuery $createSql -RawOutput | Add-Content -Path $file

    $constraintsSql = @"
SELECT 'ALTER TABLE '||quote_ident(n.nspname)||'.'||quote_ident(c.relname)||' ADD CONSTRAINT '
       ||quote_ident(ct.conname)||' '||pg_get_constraintdef(ct.oid)||';'
FROM pg_constraint ct
JOIN pg_class c ON c.oid=ct.conrelid
JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname='${Schema}' AND c.relname='${t}' AND ct.contype IN ('p','u','f')
ORDER BY ct.conindid;
"@
    Invoke-DbQuery $constraintsSql -RawOutput | Add-Content -Path $file

    $indexesSql = @"
SELECT indexdef||';' FROM pg_indexes
WHERE schemaname='${Schema}' AND tablename='${t}'
ORDER BY indexname;
"@
    Invoke-DbQuery $indexesSql -RawOutput | Add-Content -Path $file
}

foreach ($v in $schemaObjects.VIEWS) {
    $dir = Join-Path $root (Join-Path $Schema (Join-Path 'VIEWS' $v))
    Ensure-Dir $dir
    $file = Join-Path $dir "$v.sql"
    $header = @(
        "-- Source: jdbc:postgresql://127.0.0.1:5432/$DbName",
        "-- Usuario: $DbUser",
        "-- Contenedor: $DbContainerName",
        "SET LOCAL search_path TO $Schema;",
        ""
    )
    Set-Content -Path $file -Value ($header -join "`n")
    $viewSql = "SELECT 'CREATE OR REPLACE VIEW '||quote_ident('${Schema}')||'.'||quote_ident('${v}')||E' AS\n'||pg_get_viewdef('\"${Schema}\".\"${v}\"'::regclass, true)||';'"
    Invoke-DbQuery $viewSql -RawOutput | Add-Content -Path $file
}

foreach ($sig in $schemaObjects.FUNCTIONS) {
    $parts = $sig.Split('|',2)
    $fn = $parts[0]
    $args = $parts[1]
    $safe = ($fn + '_' + $args.Replace(',','_').Replace(' ','').Replace('(','').Replace(')','').Replace('[]','')).ToLower()
    $dir = Join-Path $root (Join-Path $Schema (Join-Path 'FUNCTIONS' $safe))
    Ensure-Dir $dir
    $file = Join-Path $dir "$safe.sql"
    $header = @(
        "-- Source: jdbc:postgresql://127.0.0.1:5432/$DbName",
        "-- Usuario: $DbUser",
        "-- Contenedor: $DbContainerName",
        "SET LOCAL search_path TO $Schema;",
        ""
    )
    Set-Content -Path $file -Value ($header -join "`n")
    $funcSql = "SELECT pg_get_functiondef(p.oid) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='${Schema}' AND p.proname='${fn}' AND pg_get_function_identity_arguments(p.oid)='${args}';"
    Invoke-DbQuery $funcSql -RawOutput | Add-Content -Path $file
}

foreach ($sig in $schemaObjects.PROCEDURES) {
    $parts = $sig.Split('|',2)
    $pr = $parts[0]
    $args = $parts[1]
    $safe = ($pr + '_' + $args.Replace(',','_').Replace(' ','').Replace('(','').Replace(')','').Replace('[]','')).ToLower()
    $dir = Join-Path $root (Join-Path $Schema (Join-Path 'PROCEDURES' $safe))
    Ensure-Dir $dir
    $file = Join-Path $dir "$safe.sql"
    $header = @(
        "-- Source: jdbc:postgresql://127.0.0.1:5432/$DbName",
        "-- Usuario: $DbUser",
        "-- Contenedor: $DbContainerName",
        "SET LOCAL search_path TO $Schema;",
        ""
    )
    Set-Content -Path $file -Value ($header -join "`n")
    $procSql = "SELECT pg_get_functiondef(p.oid) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='${Schema}' AND p.proname='${pr}' AND pg_get_function_identity_arguments(p.oid)='${args}';"
    Invoke-DbQuery $procSql -RawOutput | Add-Content -Path $file
}

Write-Host "Exportación completa. Carpeta: $OutputRoot/$Schema"