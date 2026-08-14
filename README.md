# DailyQuote

Tegner dagens sitat pent oppå et Windows Spotlight-bilde og setter det som skrivebordsbakgrunn.

Windows Spotlight gir deg nye bakgrunnsbilder, men ingen mulighet til å legge noe oppå dem. DailyQuote henter ferske bilder direkte fra Spotlight sitt offentlige API (samme kilde som Windows 11 bruker), tegner et sitat nederst med en mørk gradient bak, og setter resultatet som bakgrunn. Den lokale Spotlight-cachen brukes som fallback hvis API-et ikke er tilgjengelig. Du får fortsatt nye bilder gjennom dagen — bare med tekst på.

Nytt sitat i tur og orden hver kjøring, nytt bilde hver fjerde time.

## Krav

- Windows 10/11
- PowerShell 5.1 (følger med Windows)
- Internettilgang for å hente ferske bilder fra Spotlight-API-et (uten nett faller scriptet tilbake på den lokale Spotlight-cachen)

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
| `-MinWidth` | `1600` | Minste bildebredde. Filtrerer bort småbilder og portrettformat |

## Hvordan det virker

Ferske bilder hentes fra Spotlight sitt offentlige API:

```
https://fd.api.iris.microsoft.com/v4/api/selection?placement=88000820&bcnt=8&country=US&locale=en-US&fmt=json
```

`placement=88000820` er skrivebords-spotlighten. Svaret er JSON der hvert element inneholder en URL til et liggende bilde i full oppløsning (typisk 3840×2160) på Microsofts offentlige CDN (`res.public.onecdn.static.microsoft`). Scriptet laster disse ned til `%LOCALAPPDATA%\DailyQuote\spotlight\`, deduplisert på `entityId`. Vil du ha bilder tilpasset et annet land, kan du justere `country`/`locale` i URL-en.

Som fallback — hvis API-et ikke svarer — kopieres bilder fra den lokale Spotlight-cachen, som havner to steder på disk uten filendelse:

```
%LOCALAPPDATA%\Packages\Microsoft.Windows.ContentDeliveryManager_cw5n1h2txyewy\LocalState\Assets
%APPDATA%\Microsoft\Windows\Themes\CachedFiles
```

Uansett kilde forkastes det som ikke er liggende format i tilstrekkelig oppløsning, og scriptet velger tilfeldig blant resten. Bassenget blir liggende, så det vokser over tid.

Sitatene roteres gjennom i rekkefølge. Sist brukte linjeindeks lagres i `%LOCALAPPDATA%\DailyQuote\quote-state.txt`, og hver kjøring plukker neste linje og starter på nytt øverst når lista er ute. Endrer du `quotes.txt`, justeres indeksen trygt slik at den alltid holder seg innenfor lista.

Ferdig bilde lagres i `%LOCALAPPDATA%\DailyQuote\` med tidsstempel i filnavnet — Windows cacher bakgrunnen per filsti, så uten nytt navn hver gang ville ikke endringen slått gjennom. Bakgrunnen settes via `SystemParametersInfo` med `SPI_SETDESKWALLPAPER`.

## Kjent begrensning

**Spotlight-rotasjonen slås av.** Så snart en egen bakgrunn settes, slutter Windows å rotere selv. DailyQuote overtar den jobben — derav den planlagte oppgaven hver fjerde time.

Vil du ha teksten liggende oppå *levende* Spotlight, må du ha et flytende vindu over skrivebordet i stedet. Rainmeter er enkleste vei dit, eller en liten WPF-app med `WS_EX_NOACTIVATE` festet bak ikonene.

Låseskjermen støttes ikke. Windows Spotlight overstyrer den, og å sette den programmatisk krever Pro/Enterprise og PersonalizationCSP.

## Feilsøking

**«cannot be loaded ... not digitally signed»**
Filene er merket som nedlastet fra internett. `Unblock-File .\*.ps1` fjerner merket. Sjekk gjeldende policy med `Get-ExecutionPolicy -List` — `RemoteSigned` krever kun signatur på merkede filer.

**«Fant ingen Spotlight-bilder»**
Både API-henting og den lokale cachen slo feil. Sjekk internettforbindelsen. Som reserve kan du slå på Spotlight under Innstillinger → Personalisering → Bakgrunn → Windows Spotlight og la den gå et par dager, så cachen fyller seg.

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