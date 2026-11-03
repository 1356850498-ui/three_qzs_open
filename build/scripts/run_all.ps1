param([string]$VivadoBin='')
$ErrorActionPreference='Stop'
. "$PSScriptRoot/resolve_vivado.ps1"
$VivadoBin=Resolve-VivadoBin $VivadoBin
$vivado=Join-Path $VivadoBin 'vivado.bat'
$root=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
& "$PSScriptRoot/prepare_project.ps1" -VivadoBin $VivadoBin
& "$PSScriptRoot/run_qzs_simulation.ps1" -VivadoBin $VivadoBin -Only qzs,normal_spwm,arbiter,interlock,parameter,qzs_board,trace
& "$PSScriptRoot/run_simulation.ps1" -VivadoBin $VivadoBin -ProjectDir "$root/board/project_main"
& "$PSScriptRoot/run_cascade.ps1" -VivadoBin $VivadoBin
$logDir=Join-Path $root 'build/reproduction_logs'
Push-Location $logDir
try {
 foreach($cfg in @('main','d0')){
  & $vivado -mode batch -nojournal -log "build_$cfg.log" -source "$PSScriptRoot/build_cascade.tcl" -tclargs $cfg
  if($LASTEXITCODE -ne 0){throw "$cfg build failed"}
 }
 & $vivado -mode batch -nojournal -log final_project_audit.log -source "$PSScriptRoot/final_project_audit.tcl"
 if($LASTEXITCODE -ne 0){throw 'Final audit failed'}
} finally {Pop-Location}
'FULL_REPRODUCTION_RESULT=PASS'
