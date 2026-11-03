param([string]$VivadoBin='',[string[]]$Only=@('qzs','arbiter','parameter','qzs_board'),[string]$ResultRoot='')
$ErrorActionPreference='Stop'
. "$PSScriptRoot/resolve_vivado.ps1"
$VivadoBin=Resolve-VivadoBin $VivadoBin
$root=(Split-Path -Parent (Split-Path -Parent $PSScriptRoot)).Replace('\','/')
if(!$ResultRoot){$ResultRoot="$root/sim/results"}
function Invoke-X([string]$Exe,[string[]]$ToolArgs) {& (Join-Path $VivadoBin $Exe) @ToolArgs;if($LASTEXITCODE -ne 0){throw "$Exe failed $LASTEXITCODE"}}
$rtl=@(Get-ChildItem "$root/src/rtl/core/*.v","$root/src/rtl/qzs/*.v","$root/src/rtl/board/*.v" | Where-Object {$_.Name -notlike '*board_top.v'} | ForEach-Object {$_.FullName})
foreach($name in $Only){
 $run=Join-Path $ResultRoot $name;New-Item -ItemType Directory -Path $run -Force | Out-Null
 Copy-Item "$root/src/rtl/core/spwm_duty.mem" $run
 Push-Location $run
 try {
 Set-Content "result_$name.txt" 'RESULT=INCOMPLETE'
 Invoke-X 'xvlog.bat' (@('--work','xil_defaultlib')+$rtl+@('--log','compile_rtl.log'))
 Invoke-X 'xvlog.bat' @('--sv','--work','xil_defaultlib',"$root/sim/core_baseline/gate_deadline_checker.sv","$root/sim/${name}_tb.sv",'--log','compile_tb.log')
 Invoke-X 'xelab.bat' @('--debug','typical','--snapshot',"${name}_snapshot","xil_defaultlib.${name}_tb",'--log','elaborate.log')
 Invoke-X 'xsim.bat' @("${name}_snapshot",'-tclbatch',"$root/sim/run_${name}.tcl",'-wdb',"$name.wdb",'-log','simulate.log','-onerror','quit')
 $result=if($name -eq 'qzs_board'){'result_board.txt'}else{"result_$name.txt"}
 if(!(Select-String -LiteralPath $result -Pattern '^RESULT=PASS$' -Quiet)){throw "$name did not pass"}
 if($name -eq 'qzs_board'){Copy-Item -LiteralPath $result -Destination 'result_qzs_board.txt' -Force}
 if(Select-String -LiteralPath 'simulate.log' -Pattern 'FAIL|Fatal:|TIMEOUT' -Quiet){throw "$name simulation failures"}
 } finally {Pop-Location}
}

