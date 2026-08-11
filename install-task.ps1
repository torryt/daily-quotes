# Kjør én gang. Registrerer to oppgaver: ved pålogging + hver 4. time.
# Ingen admin nødvendig.

$script = Join-Path $PSScriptRoot 'daily-quote.ps1'
if (-not (Test-Path $script)) { throw "Fant ikke daily-quote.ps1 ved siden av dette scriptet." }

$action = New-ScheduledTaskAction -Execute 'powershell.exe' `
    -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$script`""

$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 5)

# Ved pålogging (litt forsinket så cachen er klar)
$t1 = New-ScheduledTaskTrigger -AtLogOn
$t1.Delay = 'PT45S'

# Og med jevne mellomrom gjennom dagen for nytt bilde
$t2 = New-ScheduledTaskTrigger -Once -At (Get-Date).Date.AddHours(7) `
    -RepetitionInterval (New-TimeSpan -Hours 4) -RepetitionDuration (New-TimeSpan -Days 3650)

Register-ScheduledTask -TaskName 'DailyQuote Wallpaper' `
    -Action $action -Trigger $t1, $t2 -Settings $settings -Force | Out-Null

Write-Host "Oppgaven er registrert. Kjører den nå..."
& $script
