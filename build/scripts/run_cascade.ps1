param([string]$Only='all',[string]$VivadoBin='',[string]$ResultRoot='')
$ErrorActionPreference='Stop'
$root=(Split-Path -Parent (Split-Path -Parent $PSScriptRoot)).Replace('\','/')
. "$PSScriptRoot/resolve_vivado.ps1"
$bin=Resolve-VivadoBin $VivadoBin
function Invoke-X([string]$exe,[string[]]$toolArgs){
    & "$bin/$exe" @toolArgs
    if($LASTEXITCODE -ne 0){throw "$exe failed: $LASTEXITCODE"}
}
$rtl=@(Get-ChildItem "$root/src/rtl/core/*.v","$root/src/rtl/qzs/*.v","$root/src/rtl/board/*.v","$root/src/rtl/cascade/*.v" | Where-Object {$_.Name -notlike '*board_top.v'} | ForEach-Object {$_.FullName})
foreach($name in @('main','d0','buttons','parameters')){
    if($Only -ne 'all' -and $Only -ne $name){continue}
    if(!$ResultRoot){$ResultRoot="$root/sim/results"}
    $run=Join-Path $ResultRoot "cascade_$name"
    New-Item -ItemType Directory -Path $run -Force | Out-Null
    Copy-Item "$root/src/rtl/core/spwm_duty.mem" $run
    Push-Location $run
    try{
        Set-Content 'result.txt' 'RESULT=INCOMPLETE'
        Invoke-X 'xvlog.bat' (@('-i',"$root/src/rtl/cascade",'--work','xil_defaultlib')+$rtl+@('--log','compile_rtl.log'))
        Invoke-X 'xvlog.bat' @('--sv','-i',"$root/src/rtl/cascade",'--work','xil_defaultlib',"$root/sim/cascade_tb.sv",'--log','compile_tb.log')
        Invoke-X 'xelab.bat' @('--debug','all','--snapshot',"cascade_${name}_snapshot","xil_defaultlib.cascade_${name}_tb",'--log','elaborate.log')
        Invoke-X 'xsim.bat' @("cascade_${name}_snapshot",'-tclbatch',"$root/sim/run_cascade_$name.tcl",'-wdb',"cascade_$name.wdb",'-log','simulate.log','-onerror','quit')
        if(!(Select-String -LiteralPath 'result.txt' -Pattern '^RESULT=PASS$' -Quiet)){throw "cascade_$name failed"}
    }finally{Pop-Location}
}
