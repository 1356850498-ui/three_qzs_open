param([string]$PythonExe='',[string]$ProjectRoot='',[string]$Config='')
$ErrorActionPreference='Stop'
$utf8=New-Object System.Text.UTF8Encoding($false)
[Console]::OutputEncoding=$utf8
$env:PYTHONIOENCODING='utf-8'
$env:PYTHONDONTWRITEBYTECODE='1'
try {
    $prefixArgs=@()
    if(!$PythonExe){
        $launcher=Get-Command py.exe -ErrorAction SilentlyContinue
        $pythonCommand=Get-Command python.exe -ErrorAction SilentlyContinue
        $bundled=Join-Path $env:USERPROFILE '.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
        if($launcher){$PythonExe=$launcher.Source;$prefixArgs=@('-3')}
        elseif($pythonCommand -and $pythonCommand.Source -notmatch '[\\/]WindowsApps[\\/]'){$PythonExe=$pythonCommand.Source}
        elseif(Test-Path -LiteralPath $bundled){$PythonExe=$bundled}
        else{throw 'Python 3.9+ not found. Install Python and enable Add python.exe to PATH.'}
    }
    & $PythonExe @prefixArgs -c "import sys; sys.exit(0 if sys.version_info >= (3,9) else 2)"
    if($LASTEXITCODE -ne 0){throw 'Python 3.9+ is required.'}
    $toolArgs=@((Join-Path $PSScriptRoot 'scripts\run_check.py'))
    if($ProjectRoot){$toolArgs+=@('--project-root',$ProjectRoot)}
    if($Config){$toolArgs+=@('--config',$Config)}
    & $PythonExe @prefixArgs @toolArgs
    exit $LASTEXITCODE
} catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 2
}
