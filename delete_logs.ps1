$path = "C:\ProgramData\Microsoft\Diagnosis\ETLLogs"

$sizeBefore = (Get-ChildItem -LiteralPath $path -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
if ($null -eq $sizeBefore) { $sizeBefore = 0 }

$items = Get-ChildItem -LiteralPath $path -Force -ErrorAction SilentlyContinue
$failed = @()

foreach ($i in $items) {
    try {
        Remove-Item -LiteralPath $i.FullName -Recurse -Force -ErrorAction Stop
    }
    catch {
        $ex = $_.Exception
        $failed += [pscustomobject]@{
            Path      = $i.FullName
            Type      = $ex.GetType().FullName
            HResult   = ('0x{0:X8}' -f $ex.HResult)
            Message   = $ex.Message
        }
    }
}

$sizeAfter = (Get-ChildItem -LiteralPath $path -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
if ($null -eq $sizeAfter) { $sizeAfter = 0 }

$freed = $sizeBefore - $sizeAfter
"{0:N2} MB freed" -f ($freed / 1MB)
"Failed items: $($failed.Count)"

if ($failed.Count -gt 0) {
    $failed | Format-Table -Auto
}
