param([string]$ProjectRoot=(Split-Path -Parent (Split-Path -Parent $PSScriptRoot)))
$ErrorActionPreference='Stop'
$bad=@()
$rows=Import-Csv -LiteralPath (Join-Path $ProjectRoot 'report/audit/submission_manifest.csv')
foreach($r in $rows){
 $p=Join-Path $ProjectRoot $r.relative_path
 if(!(Test-Path -LiteralPath $p)){$bad+="MISSING $($r.relative_path)";continue}
 if((Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLowerInvariant() -ne $r.sha256){$bad+="CHANGED $($r.relative_path)"}
}
if($bad.Count){$bad|Write-Output;throw "Verification failed: $($bad.Count)"}
"FILES=$($rows.Count)"
'RESULT=PASS'
