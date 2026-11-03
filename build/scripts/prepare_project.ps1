param([string]$VivadoBin='')
$ErrorActionPreference='Stop'
. "$PSScriptRoot/resolve_vivado.ps1"
$VivadoBin=Resolve-VivadoBin $VivadoBin
$root=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$logDir=Join-Path $root 'build/reproduction_logs'
New-Item -ItemType Directory -Path $logDir -Force | Out-Null
foreach($cfg in @('main','d0')){
    $project=Join-Path $root "board/project_$cfg/cascade_qzs.xpr"
    if(Test-Path -LiteralPath $project){Write-Output "EXISTS=$project";continue}
    Push-Location $logDir
    try {
        & (Join-Path $VivadoBin 'vivado.bat') -mode batch -nojournal -log "prepare_$cfg.log" -source "$PSScriptRoot/create_cascade.tcl" -tclargs $cfg
        if($LASTEXITCODE -ne 0){throw "Project creation failed: $cfg"}
    } finally {Pop-Location}
    if(!(Test-Path -LiteralPath $project)){throw "Project file missing: $project"}
    Write-Output "CREATED=$project"
}
Push-Location $logDir
try {
    & (Join-Path $VivadoBin 'vivado.bat') -mode batch -nojournal -log inspect_projects.log -source "$PSScriptRoot/inspect_projects.tcl"
    if($LASTEXITCODE -ne 0){throw 'Project dependency check failed; see build/reproduction_logs/inspect_projects.log'}
} finally {Pop-Location}
'PREPARE_RESULT=PASS'
