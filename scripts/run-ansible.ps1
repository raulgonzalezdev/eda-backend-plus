Param(
    [string]$Playbook = "ansible/playbooks/generate_db_migration.yml",
    [string]$VarsFile = "ansible/vars/dev.yml",
    [string]$DockerNetwork = "",
    [string]$ExtraVars = ""
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $repoRoot

function Has-Ansible() {
    try { Get-Command ansible-playbook -ErrorAction Stop | Out-Null; return $true } catch { return $false }
}

if (Has-Ansible) {
    $ansCmd = @('ansible-playbook', $Playbook)
    if (Test-Path $VarsFile) { $ansCmd += @('-e', "@$VarsFile") }
    if ($ExtraVars -and $ExtraVars.Trim().Length -gt 0) { $ansCmd += @('-e', $ExtraVars) }
    & $ansCmd[0] $ansCmd[1..($ansCmd.Length-1)]
} else {
    $pwd = (Resolve-Path $repoRoot).Path
    $dockerArgs = @('run','--rm','-v',"$($pwd):/workspace",'-w','/workspace')
    if ($DockerNetwork -and $DockerNetwork.Trim().Length -gt 0) { $dockerArgs += @('--network',$DockerNetwork) }
    # Build the ansible-playbook command to run inside the container
    $ansCmd = @('ansible-playbook', $Playbook)
    if (Test-Path $VarsFile) { $ansCmd += @('-e', "@$VarsFile") }
    if ($ExtraVars -and $ExtraVars.Trim().Length -gt 0) { $ansCmd += @('-e', $ExtraVars) }
    $dockerArgs += @('cytopia/ansible:latest') + $ansCmd
    & 'docker' $dockerArgs
}