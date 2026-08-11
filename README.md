# DailyQuote

Tegner dagens sitat pent oppå et Windows Spotlight-bilde og setter det som skrivebordsbakgrunn.

Windows Spotlight gir deg nye bakgrunnsbilder, men ingen mulighet til å legge noe oppå dem. DailyQuote plukker bilder fra Spotlight-cachen som Windows fyller opp uansett, tegner et sitat nederst med en mørk gradient bak, og setter resultatet som bakgrunn. Du får fortsatt nye bilder gjennom dagen — bare med tekst på.

Samme sitat hele dagen, nytt bilde hver fjerde time.

## Krav

- Windows 10/11
- PowerShell 5.1 (følger med Windows)
- Windows Spotlight aktivert i minst et par dager, slik at bildecachen har rukket å fylle seg

## Kom i gang

Legg alle filene i samme mappe, f.eks. `C:\dev\tools\DailyQuote\`:

```powershell
Unblock-File .\*.ps1     # fjerner nedlastingsmerket
.\install-task.ps1
```

`install-task.ps1` registrerer en planlagt oppgave (ingen admin nødvendig) og kjører scriptet med én gang, så du ser resultatet umiddelbart.

For å teste uten å registrere noe:

```powershell
.\daily-quote.ps1
```

## Filer

| Fil | Hva den gjør |
| --- | --- |
| `daily-quote.ps1` | Selve jobben: velger sitat og bilde, tegner, setter bakgrunn |
| `quotes.txt` | Sitatene, ett per linje, UTF-8 |
| `install-task.ps1` | Registrerer planlagt oppgave ved pålogging + hver 4. time |

## Egne sitater

Rediger `quotes.txt` — ett sitat per linje. Filen leses ved hver kjøring, så du trenger ikke registrere oppgaven på nytt. Lagre som UTF-8 hvis du bruker æ, ø og å.

Korte sitater ser best ut. Fonten skalerer automatisk ned hvis teksten er for lang til å få plass, men under ca. 60 tegn holder seg på én til to linjer.

## Parametere

```powershell
.\daily-quote.ps1 -Position BottomCenter
```

| Parameter | Standard | Beskrivelse |
| --- | --- | --- |
| `-QuotesFile` | `.\quotes.txt` | Sti til sitatfilen |
| `-Position` | `BottomLeft` | `BottomLeft`, `BottomCenter` eller `Center` |
| `-MinWidth` | `1600` | Minste bildebredde. Filtrerer bort småbilder og portrettformat fra Spotlight-cachen |

## Hvordan det virker

Spotlight-bilder havner to steder på disk, uten filendelse:

```
%LOCALAPPDATA%\Packages\Microsoft.Windows.ContentDeliveryManager_cw5n1h2txyewy\LocalState\Assets
%APPDATA%\Microsoft\Windows\Themes\CachedFiles
```

Scriptet kopierer alt over 250 KB derfra til `%LOCALAPPDATA%\DailyQuote\spotlight\`, forkaster det som ikke er liggende format i tilstrekkelig oppløsning, og velger tilfeldig blant resten. Bassenget blir liggende, så det vokser over tid selv når Windows rydder i sin egen cache.

Sitatvalget seedes på dagens dato (`yyyyMMdd`), som gir samme sitat gjennom hele dagen og et nytt neste morgen.

Ferdig bilde lagres i `%LOCALAPPDATA%\DailyQuote\` med tidsstempel i filnavnet — Windows cacher bakgrunnen per filsti, så uten nytt navn hver gang ville ikke endringen slått gjennom. Bakgrunnen settes via `SystemParametersInfo` med `SPI_SETDESKWALLPAPER`.

## Kjent begrensning

**Spotlight-rotasjonen slås av.** Så snart en egen bakgrunn settes, slutter Windows å rotere selv. DailyQuote overtar den jobben — derav den planlagte oppgaven hver fjerde time.

Vil du ha teksten liggende oppå *levende* Spotlight, må du ha et flytende vindu over skrivebordet i stedet. Rainmeter er enkleste vei dit, eller en liten WPF-app med `WS_EX_NOACTIVATE` festet bak ikonene.

Låseskjermen støttes ikke. Windows Spotlight overstyrer den, og å sette den programmatisk krever Pro/Enterprise og PersonalizationCSP.

## Feilsøking

**«cannot be loaded ... not digitally signed»**
Filene er merket som nedlastet fra internett. `Unblock-File .\*.ps1` fjerner merket. Sjekk gjeldende policy med `Get-ExecutionPolicy -List` — `RemoteSigned` krever kun signatur på merkede filer.

**«Fant ingen Spotlight-bilder»**
Cachen er tom. Slå på Spotlight under Innstillinger → Personalisering → Bakgrunn → Windows Spotlight, og la den gå et par dager før du kjører scriptet.

**Bakgrunnen endrer seg ikke**
Sjekk at oppgaven finnes og har kjørt:

```powershell
Get-ScheduledTask -TaskName 'DailyQuote Wallpaper' | Get-ScheduledTaskInfo
```

## Avinstallering

```powershell
Unregister-ScheduledTask -TaskName 'DailyQuote Wallpaper' -Confirm:$false
Remove-Item "$env:LOCALAPPDATA\DailyQuote" -Recurse -Force
```

Sett så bakgrunnen tilbake til Spotlight under Innstillinger → Personalisering → Bakgrunn.