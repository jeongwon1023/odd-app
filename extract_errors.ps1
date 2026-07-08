$v = "C:\dev\verbose.txt"
if (!(Test-Path $v)) { Write-Host "verbose.txt not found"; exit }

$lines = Get-Content $v
$out = @()

for ($i = 0; $i -lt $lines.Count; $i++) {
    $l = $lines[$i]
    if ($l -match "(?i)(error|FAIL|Exception|stderr|e:)" -and
        $l -notmatch "(?i)(warning|obsolete|future|KGP|deprecat|configure|checkKotlin|builtIn)") {
        # context: 2 lines before and after
        $start = [Math]::Max(0, $i-2)
        $end   = [Math]::Min($lines.Count-1, $i+2)
        $out += "--- line $i ---"
        $out += $lines[$start..$end]
        $out += ""
    }
}

if ($out.Count -eq 0) {
    # fallback: last 80 lines
    $out = $lines | Select-Object -Last 80
}

$out | Set-Content "C:\Users\chahy\OneDrive\문서\GitHub\odd-app\build_errors.txt"
Write-Host "Done → build_errors.txt saved to OneDrive"
