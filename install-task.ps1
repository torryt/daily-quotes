# Run once. Registers two tasks: on login + every 4 hours.
# No admin required.

$script = Join-Path $PSScriptRoot 'daily-quote.ps1'
if (-not (Test-Path $script)) { throw "Could not find daily-quote.ps1 next to this script." }

$action = New-ScheduledTaskAction -Execute 'powershell.exe' `
    -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$script`""

$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 5)

# On login (slightly delayed so cache is ready)
$t1 = New-ScheduledTaskTrigger -AtLogOn
$t1.Delay = 'PT45S'

# And at regular intervals during the day for a new image
$t2 = New-ScheduledTaskTrigger -Once -At (Get-Date).Date.AddHours(7) `
    -RepetitionInterval (New-TimeSpan -Hours 4) -RepetitionDuration (New-TimeSpan -Days 3650)

Register-ScheduledTask -TaskName 'DailyQuote Wallpaper' `
    -Action $action -Trigger $t1, $t2 -Settings $settings -Force | Out-Null

Write-Host "Task registered. Running it now..."
& $script
