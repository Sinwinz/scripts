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
            Path    = $i.FullName
            Type    = $ex.GetType().FullName
            HResult = ('0x{0:X8}' -f $ex.HResult)
            Message = $ex.Message
        }
    }
}

$sizeAfter = (Get-ChildItem -LiteralPath $path -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
if ($null -eq $sizeAfter) { $sizeAfter = 0 }

$freed = $sizeBefore - $sizeAfter
"{0:N2} MB freed (ETLLogs)" -f ($freed / 1MB)
"Failed items (ETLLogs): $($failed.Count)"
if ($failed.Count -gt 0) { $failed | Format-Table -Auto }

$svcName = "telegraf data collector service"
$telegrafLog = "C:\Program Files\telegraf\telegraf.log"
$telegrafStep = $null

$svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
if ($null -ne $svc) {
    $wasRunning = $svc.Status -eq 'Running'
    try {
        if ($wasRunning) {
            Stop-Service -Name $svcName -Force -ErrorAction Stop
            $svc.WaitForStatus('Stopped', (New-TimeSpan -Seconds 30))
        }

        if (Test-Path -LiteralPath $telegrafLog) {
            $before = (Get-Item -LiteralPath $telegrafLog -ErrorAction Stop).Length
            Set-Content -LiteralPath $telegrafLog -Value $null -Encoding UTF8 -ErrorAction Stop
            $after = (Get-Item -LiteralPath $telegrafLog -ErrorAction SilentlyContinue).Length
            if ($null -eq $after) { $after = 0 }
            $telegrafStep = [pscustomobject]@{
                ServiceFound = $true
                LogFound     = $true
                Cleared      = $true
                FreedMB      = [math]::Round((($before - $after) / 1MB), 2)
            }
        }
        else {
            $telegrafStep = [pscustomobject]@{
                ServiceFound = $true
                LogFound     = $false
                Cleared      = $false
            }
        }
    }
    catch {
        $ex = $_.Exception
        $telegrafStep = [pscustomobject]@{
            ServiceFound = $true
            LogFound     = (Test-Path -LiteralPath $telegrafLog)
            Cleared      = $false
            Type         = $ex.GetType().FullName
            HResult      = ('0x{0:X8}' -f $ex.HResult)
            Message      = $ex.Message
        }
    }
    finally {
        if ($wasRunning) {
            try {
                Start-Service -Name $svcName -ErrorAction SilentlyContinue
            } catch {}
        }
    }
}

if ($null -eq $svc) {
    "Telegraf service not found, step skipped"
}
elseif ($null -ne $telegrafStep -and $telegrafStep.LogFound -eq $false) {
    "Telegraf service found, but log file not found, step skipped"
}
elseif ($null -ne $telegrafStep -and $telegrafStep.Cleared) {
    "Telegraf log cleared: $($telegrafStep.FreedMB) MB freed"
}
elseif ($null -ne $telegrafStep -and $telegrafStep.ServiceFound) {
    "Telegraf log clear failed: $($telegrafStep.Message) [$($telegrafStep.HResult)]"
}
