param([string]$VivadoBin='',[string[]]$Only=@('equivalence','board','core','deadtime','compare','reset'),[string]$ProjectDir='',[string]$ResultRoot='')
$ErrorActionPreference='Stop'
. "$PSScriptRoot/resolve_vivado.ps1"
$VivadoBin=Resolve-VivadoBin $VivadoBin
$root=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if(!$ProjectDir){$ProjectDir=Join-Path $root 'board/project_main'}
$vivadoRoot=Split-Path -Parent $VivadoBin
if(!$ResultRoot){$ResultRoot=Join-Path $root 'sim\results'}
New-Item -ItemType Directory -Path $resultRoot -Force | Out-Null
Set-Content -LiteralPath (Join-Path $resultRoot 'overall_result.txt') 'RESULT=INCOMPLETE'
function Invoke-X([string]$Exe,[string[]]$ToolArgs) {
    & (Join-Path $VivadoBin $Exe) @ToolArgs
    if($LASTEXITCODE -ne 0){throw "$Exe failed with exit $LASTEXITCODE"}
}
$core=@(Get-ChildItem -LiteralPath (Join-Path $root 'src\rtl\core') -Filter '*.v' | ForEach-Object {$_.FullName})
$core+=@(Get-ChildItem -LiteralPath (Join-Path $root 'src/rtl/qzs') -Filter '*.v' | ForEach-Object {$_.FullName})
$board=@(Get-ChildItem -LiteralPath (Join-Path $root 'src\rtl\board') -Filter '*.v' | Where-Object {$_.Name -notlike '*board_top.v'} | ForEach-Object {$_.FullName})
$tests=@(@('equivalence','compare_equivalence_tb','run_equivalence.tcl'),@('board','board_tb','run_board.tcl'),@('core','hbridge_spwm_tb','run_core.tcl'),@('deadtime','deadtime_half_bridge_tb','run_unit.tcl'),@('compare','compare_pair_tb','run_unit.tcl'),@('reset','reset_tb','run_unit.tcl'))
foreach($test in $tests) {
    $name=$test[0];$top=$test[1];$run=Join-Path $resultRoot $name
    if($name -notin $Only){continue}
    New-Item -ItemType Directory -Path $run -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $root 'src\rtl\core\spwm_duty.mem') -Destination $run
    Push-Location $run
    try {
        Set-Content "result_$name.txt" 'RESULT=INCOMPLETE'
        if($name -eq 'equivalence') {
            Invoke-X 'xvlog.bat' @('--work','xil_defaultlib',(Join-Path $root 'src\rtl\core\spwm_compare_pair.v'),(Join-Path $root 'sim\reference\spwm_compare_pair_before.v'),'--log','compile_rtl.log')
            Invoke-X 'xvlog.bat' @('--sv','--work','xil_defaultlib',(Join-Path $root 'sim\compare_equivalence_tb.sv'),'--log','compile_tb.log')
        } elseif($name -eq 'reset') {
            Invoke-X 'xvhdl.bat' @('--work','proc_sys_reset_v5_0_17',(Join-Path $vivadoRoot 'data\ip\xilinx\proc_sys_reset_v5_0\hdl\proc_sys_reset_v5_0_vh_rfs.vhd'),'--log','compile_vendor.log')
            $ip=Get-ChildItem -LiteralPath (Join-Path $ProjectDir 'cascade_qzs.gen\sources_1\bd\ps_clock_reset\ip') -Filter 'ps_clock_reset_rst_100m_0.vhd' -Recurse | Where-Object {$_.Directory.Name -eq 'sim'} | Select-Object -First 1
            if(!$ip){throw 'Generated reset IP simulation wrapper not found'}
            Invoke-X 'xvhdl.bat' @('--work','xil_defaultlib',$ip.FullName,'--log','compile_ip.log')
            Invoke-X 'xvlog.bat' @('--work','xil_defaultlib',(Join-Path $root 'src\rtl\board\board_reset_sync.v'),'--log','compile_rtl.log')
            Invoke-X 'xvlog.bat' @('--work','xil_defaultlib',(Join-Path $vivadoRoot 'data\verilog\src\glbl.v'),'--log','compile_glbl.log')
            Invoke-X 'xvlog.bat' @('--sv','--work','xil_defaultlib',(Join-Path $root 'sim\reset_tb.sv'),'--log','compile_tb.log')
        } else {
            Invoke-X 'xvlog.bat' (@('--work','xil_defaultlib')+$core+$board+@('--log','compile_rtl.log'))
            $tb=if($name -eq 'board'){Join-Path $root 'sim\board_tb.sv'}else{Join-Path $root "sim\core_baseline\$top.sv"}
            Invoke-X 'xvlog.bat' @('--sv','--work','xil_defaultlib',(Join-Path $root 'sim\core_baseline\gate_deadline_checker.sv'),$tb,'--log','compile_tb.log')
        }
        $elabArgs=@('--debug','typical','--snapshot',"${name}_snapshot","xil_defaultlib.$top",'-L','unisims_ver','-L','unimacro_ver','--log','elaborate.log')
        if($name -eq 'reset'){$elabArgs+=@('xil_defaultlib.glbl')}
        Invoke-X 'xelab.bat' $elabArgs
        $tcl=if($name -in @('board','equivalence')){Join-Path $root "sim\$($test[2])"}else{Join-Path $root "sim\core_baseline\$($test[2])"}
        Invoke-X 'xsim.bat' @("${name}_snapshot",'-tclbatch',$tcl.Replace('\','/'),'-wdb',"$name.wdb",'-log','simulate.log','-onerror','quit')
        if(!(Select-String -LiteralPath "result_$name.txt" -Pattern '^RESULT=PASS$' -Quiet)){throw "Simulation $name did not pass"}
        if(Select-String -LiteralPath 'simulate.log' -Pattern 'FAIL|Fatal:|TIMEOUT' -Quiet){throw "Simulation $name has failures"}
    } finally {Pop-Location}
}
$allPassed=$true
foreach($name in @('equivalence','board','core','deadtime','compare','reset')){
    $r=Join-Path $resultRoot "$name\result_$name.txt"
    if(!(Test-Path $r) -or !(Select-String -LiteralPath $r -Pattern '^RESULT=PASS$' -Quiet)){$allPassed=$false}
}
if($allPassed){Set-Content -LiteralPath (Join-Path $resultRoot 'overall_result.txt') 'RESULT=PASS'}

