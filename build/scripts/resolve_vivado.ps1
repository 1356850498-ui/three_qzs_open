function Resolve-VivadoBin {
    param([string]$Requested='')
    $candidates=@()
    if($Requested){$candidates += $Requested}
    elseif($env:VIVADO_BIN){$candidates += $env:VIVADO_BIN}
    else {
        $command=Get-Command vivado.bat -ErrorAction SilentlyContinue | Select-Object -First 1
        if($command){$candidates += Split-Path -Parent $command.Source}
        $candidates += @('C:\AMDDesignTools\2025.2\Vivado\bin','D:\AMDDesignTools\2025.2\Vivado\bin','C:\Xilinx\Vivado\2025.2\bin','D:\Xilinx\Vivado\2025.2\bin')
    }
    foreach($candidate in $candidates){
        if(Test-Path -LiteralPath (Join-Path $candidate 'vivado.bat')){
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }
    throw 'Vivado not found. Set VIVADO_BIN to the Vivado 2025.2 bin directory, or pass -VivadoBin.'
}
