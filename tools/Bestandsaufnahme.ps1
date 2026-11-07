<#
.SYNOPSIS
    NOXARION Phase 1 - rein lesende Bestandsaufnahme eines Windows-PCs.

.DESCRIPTION
    Erfasst Windows-Version, Hardware, Datentraeger, Speicherbelegung, installierte
    Programme, Autostart, Dienste, Prozesse, Entwicklungs-/KI-Werkzeuge,
    NOXARION-/LARA-Dateien sowie Netzwerk-, Bluetooth-, USB-, Audio- und Grafikstatus.

    Das Skript AENDERT NICHTS am System. Es loescht, verschiebt, deinstalliert,
    stoppt oder konfiguriert nichts. Es schreibt ausschliesslich einen neuen
    Berichtsordner (JSON + Markdown + Fehlerprotokoll) auf den Desktop.

    Laeuft mit normalen Benutzerrechten. Einzelne Angaben (z. B. Wiederherstellungs-
    punkte) brauchen Adminrechte; fehlen sie, wird das im Bericht vermerkt.

.PARAMETER Anonymisieren
    Ersetzt Benutzername und Computername im Bericht durch Platzhalter,
    damit der Bericht leichter weitergegeben werden kann.

.PARAMETER Ausgabeordner
    Optionaler Zielordner. Standard: Desktop\NOXARION-Bestandsaufnahme\<Zeitstempel>

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Bestandsaufnahme.ps1 -Anonymisieren
#>
[CmdletBinding()]
param(
    [switch]$Anonymisieren,
    [string]$Ausgabeordner
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$script:Fehler = New-Object System.Collections.Generic.List[string]
$script:Bericht = [ordered]@{}
$script:IstAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

function Invoke-Abschnitt {
    param([string]$Name, [scriptblock]$Block)
    Write-Host ("[..] {0}" -f $Name)
    $start = Get-Date
    try {
        $script:Bericht[$Name] = & $Block
        Write-Host ("[OK] {0} ({1:N1} s)" -f $Name, ((Get-Date) - $start).TotalSeconds) -ForegroundColor Green
    } catch {
        $msg = "{0}: {1}" -f $Name, $_.Exception.Message
        $script:Fehler.Add($msg)
        $script:Bericht[$Name] = @{ Fehler = $_.Exception.Message }
        Write-Host ("[!!] {0}" -f $msg) -ForegroundColor Yellow
    }
}

function Try-Get {
    # Fuehrt einen Block aus und liefert bei Fehlern einen Hinweis statt Abbruch.
    param([string]$Was, [scriptblock]$Block)
    try { & $Block } catch {
        $script:Fehler.Add(("{0}: {1}" -f $Was, $_.Exception.Message))
        "Nicht ermittelt ({0})" -f $_.Exception.Message
    }
}

function Format-GB { param($Bytes) if ($null -eq $Bytes) { return $null } [math]::Round(([double]$Bytes) / 1GB, 2) }

function Get-OrdnerGroesse {
    # Eigene Rekursion: folgt KEINEN Verknuepfungen/Junctions (ReparsePoints),
    # damit nichts ausserhalb des Ordners gezaehlt wird und keine Schleifen entstehen.
    param([string]$Pfad)
    $summe = [long]0; $dateien = [long]0; $unlesbar = 0
    if (-not (Test-Path -LiteralPath $Pfad)) { return $null }
    $stapel = New-Object System.Collections.Generic.Stack[string]
    $stapel.Push($Pfad)
    while ($stapel.Count -gt 0) {
        $akt = $stapel.Pop()
        try {
            $di = New-Object System.IO.DirectoryInfo($akt)
            foreach ($e in $di.EnumerateFileSystemInfos()) {
                if ($e.Attributes -band [IO.FileAttributes]::ReparsePoint) { continue }
                if ($e -is [IO.DirectoryInfo]) { $stapel.Push($e.FullName) }
                else { $summe += $e.Length; $dateien++ }
            }
        } catch { $unlesbar++ }
    }
    [ordered]@{ Pfad = $Pfad; GroesseGB = (Format-GB $summe); Dateien = $dateien; NichtLesbareOrdner = $unlesbar }
}

function Get-WerkzeugVersion {
    # Startet ein Werkzeug nur mit Versionsabfrage, mit 15 s Zeitlimit.
    # App-Ausfuehrungsaliase aus \WindowsApps\ werden NICHT gestartet
    # (der Python-Alias wuerde sonst ggf. den Microsoft Store oeffnen).
    param([string]$Pfad, [string]$Argumente = '--version')
    if ($Pfad -like '*\WindowsApps\*') { return 'App-Ausfuehrungsalias - nicht gestartet' }
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $Pfad; $psi.Arguments = $Argumente
        $psi.UseShellExecute = $false; $psi.CreateNoWindow = $true
        $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true
        $p = [System.Diagnostics.Process]::Start($psi)
        $outTask = $p.StandardOutput.ReadToEndAsync(); $errTask = $p.StandardError.ReadToEndAsync()
        if (-not $p.WaitForExit(15000)) { try { $p.Kill() } catch {}; return 'Zeitlimit ueberschritten' }
        $txt = ($outTask.Result + ' ' + $errTask.Result).Trim()
        if ($txt.Length -gt 300) { $txt = $txt.Substring(0, 300) }
        return (($txt -replace "`0", '') -replace '\s+', ' ')
    } catch { return ("Nicht ermittelt ({0})" -f $_.Exception.Message) }
}

# ---------------------------------------------------------------- Abschnitte

Invoke-Abschnitt 'Meta' {
    [ordered]@{
        Zeitpunkt         = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz')
        Skript            = 'NOXARION Bestandsaufnahme 1.0 (rein lesend)'
        PowerShell        = $PSVersionTable.PSVersion.ToString()
        Adminrechte       = $script:IstAdmin
        Anonymisiert      = [bool]$Anonymisieren
    }
}

Invoke-Abschnitt 'System' {
    $os = Get-CimInstance Win32_OperatingSystem
    $cs = Get-CimInstance Win32_ComputerSystem
    $bios = Get-CimInstance Win32_BIOS
    $cv = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    $displayVersion = $null
    if ($cv.PSObject.Properties.Name -contains 'DisplayVersion') { $displayVersion = $cv.DisplayVersion }
    [ordered]@{
        Computername     = $env:COMPUTERNAME
        Betriebssystem   = $os.Caption
        Version          = $os.Version
        Build            = ('{0}.{1}' -f $cv.CurrentBuild, $cv.UBR)
        Funktionsupdate  = $displayVersion
        Architektur      = $os.OSArchitecture
        Installiert      = $os.InstallDate.ToString('yyyy-MM-dd')
        LetzterStart     = $os.LastBootUpTime.ToString('yyyy-MM-dd HH:mm')
        LaufzeitStunden  = [math]::Round(((Get-Date) - $os.LastBootUpTime).TotalHours, 1)
        Hersteller       = $cs.Manufacturer
        Modell           = $cs.Model
        BIOS             = ('{0} {1}' -f $bios.Manufacturer, $bios.SMBIOSBIOSVersion)
        BIOSDatum        = $(if ($bios.ReleaseDate) { $bios.ReleaseDate.ToString('yyyy-MM-dd') } else { $null })
        Neustart_ausstehend = (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') -or
                              (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending')
    }
}

Invoke-Abschnitt 'Hardware' {
    $cpu = @(Get-CimInstance Win32_Processor | ForEach-Object {
        [ordered]@{ Name = $_.Name.Trim(); Kerne = $_.NumberOfCores; Threads = $_.NumberOfLogicalProcessors; MaxMHz = $_.MaxClockSpeed }
    })
    $ramModule = @(Get-CimInstance Win32_PhysicalMemory | ForEach-Object {
        [ordered]@{ Steckplatz = $_.DeviceLocator; GB = (Format-GB $_.Capacity); MHz = $_.Speed; Hersteller = $_.Manufacturer; Teil = ([string]$_.PartNumber).Trim() }
    })
    $os = Get-CimInstance Win32_OperatingSystem
    # VRAM: Win32_VideoController.AdapterRAM ist auf 4 GB begrenzt (32 Bit).
    # Genauer ist qwMemorySize aus der Treiber-Registry; beides wird angegeben.
    $vramReg = @{}
    $klasse = 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}'
    Get-ChildItem $klasse -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -match '^\d{4}$' } | ForEach-Object {
        $p = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
        if ($p -and ($p.PSObject.Properties.Name -contains 'HardwareInformation.qwMemorySize') -and ($p.PSObject.Properties.Name -contains 'DriverDesc')) {
            $vramReg[$p.DriverDesc] = [long]$p.'HardwareInformation.qwMemorySize'
        }
    }
    $gpu = @(Get-CimInstance Win32_VideoController | ForEach-Object {
        $reg = $null; if ($vramReg.ContainsKey($_.Name)) { $reg = Format-GB $vramReg[$_.Name] }
        [ordered]@{
            Name = $_.Name; Treiberversion = $_.DriverVersion
            Treiberdatum = $(if ($_.DriverDate) { $_.DriverDate.ToString('yyyy-MM-dd') } else { $null })
            VRAM_GB_Registry = $reg; VRAM_GB_WMI_max4GB = (Format-GB $_.AdapterRAM)
            Aufloesung = $(if ($_.CurrentHorizontalResolution) { '{0}x{1} @ {2} Hz' -f $_.CurrentHorizontalResolution, $_.CurrentVerticalResolution, $_.CurrentRefreshRate } else { $null })
            Status = $_.Status
        }
    })
    $physisch = Try-Get 'PhysicalDisk' {
        @(Get-PhysicalDisk | ForEach-Object {
            [ordered]@{ Name = $_.FriendlyName; Typ = [string]$_.MediaType; Bus = [string]$_.BusType; GB = (Format-GB $_.Size); Zustand = [string]$_.HealthStatus; Betrieb = [string]$_.OperationalStatus }
        })
    }
    [ordered]@{
        CPU = $cpu
        RAM_Gesamt_GB = (Format-GB ((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory))
        RAM_Frei_GB = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
        RAM_Module = $ramModule
        Grafik = $gpu
        Datentraeger = $physisch
    }
}

Invoke-Abschnitt 'Speicher' {
    $volumes = @(Get-CimInstance Win32_LogicalDisk | ForEach-Object {
        $belegt = $null; $prozent = $null
        if ($_.Size) { $belegt = $_.Size - $_.FreeSpace; $prozent = [math]::Round(100 * $belegt / $_.Size, 1) }
        [ordered]@{
            Laufwerk = $_.DeviceID; Bezeichnung = $_.VolumeName; Dateisystem = $_.FileSystem
            Typ = @{0='Unbekannt';1='Kein Stammverz.';2='Wechseldatentraeger';3='Lokal';4='Netzwerk';5='CD/DVD';6='RAM-Disk'}[[int]$_.DriveType]
            GroesseGB = (Format-GB $_.Size); FreiGB = (Format-GB $_.FreeSpace); BelegtProzent = $prozent
        }
    })
    $profil = $env:USERPROFILE
    $ordner = @(
        [Environment]::GetFolderPath('Desktop'),
        [Environment]::GetFolderPath('MyDocuments'),
        (Join-Path $profil 'Downloads'),
        [Environment]::GetFolderPath('MyPictures'),
        [Environment]::GetFolderPath('MyVideos'),
        [Environment]::GetFolderPath('MyMusic'),
        (Join-Path $profil 'OneDrive'),
        (Join-Path $profil '.ollama'),
        (Join-Path $profil '.cache'),
        $env:TEMP,
        (Join-Path $env:WINDIR 'Temp'),
        (Join-Path $env:LOCALAPPDATA 'Packages'),
        (Join-Path $env:LOCALAPPDATA 'Programs')
    ) | Where-Object { $_ } | Select-Object -Unique
    $groessen = @($ordner | ForEach-Object { Get-OrdnerGroesse $_ } | Where-Object { $_ })
    $papierkorb = Try-Get 'Papierkorb' {
        $shell = New-Object -ComObject Shell.Application
        [ordered]@{ Elemente = $shell.Namespace(10).Items().Count }
    }
    [ordered]@{ Laufwerke = $volumes; Ordnergroessen = ($groessen | Sort-Object { [double]$_.GroesseGB } -Descending); Papierkorb = $papierkorb }
}

Invoke-Abschnitt 'Programme' {
    $schluessel = @(
        @{ Pfad = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'; Bereich = 'Alle Benutzer (64 Bit)' },
        @{ Pfad = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'; Bereich = 'Alle Benutzer (32 Bit)' },
        @{ Pfad = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'; Bereich = 'Nur dieser Benutzer' }
    )
    $liste = foreach ($s in $schluessel) {
        Get-ItemProperty $s.Pfad -ErrorAction SilentlyContinue | ForEach-Object {
            $n = $_.PSObject.Properties.Name
            if (-not ($n -contains 'DisplayName') -or [string]::IsNullOrWhiteSpace($_.DisplayName)) { return }
            if (($n -contains 'SystemComponent') -and $_.SystemComponent -eq 1) { return }
            [ordered]@{
                Name = $_.DisplayName
                Version = $(if ($n -contains 'DisplayVersion') { $_.DisplayVersion } else { $null })
                Herausgeber = $(if ($n -contains 'Publisher') { $_.Publisher } else { $null })
                InstalliertAm = $(if ($n -contains 'InstallDate') { $_.InstallDate } else { $null })
                GroesseMB = $(if ($n -contains 'EstimatedSize' -and $_.EstimatedSize) { [math]::Round($_.EstimatedSize / 1024, 1) } else { $null })
                Ort = $(if ($n -contains 'InstallLocation') { $_.InstallLocation } else { $null })
                Bereich = $s.Bereich
            }
        }
    }
    $liste = @($liste | Sort-Object { $_.Name } -Unique)
    $apps = Try-Get 'AppxPackage' {
        @(Get-AppxPackage | Where-Object { -not $_.IsFramework } | Sort-Object Name | ForEach-Object {
            [ordered]@{ Name = $_.Name; Version = $_.Version; Herausgeber = $_.Publisher -replace '^CN=([^,]+).*', '$1'; Signatur = [string]$_.SignatureKind }
        })
    }
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    [ordered]@{
        Anzahl_Desktop = $liste.Count
        Desktop = $liste
        Anzahl_StoreApps = @($apps).Count
        StoreApps = $apps
        Winget = $(if ($winget) { Get-WerkzeugVersion $winget.Source } else { 'Nicht gefunden' })
    }
}

Invoke-Abschnitt 'Autostart' {
    $run = foreach ($k in 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run',
                          'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run',
                          'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run') {
        $p = Get-ItemProperty $k -ErrorAction SilentlyContinue
        if ($p) {
            $p.PSObject.Properties | Where-Object { $_.Name -notlike 'PS*' } | ForEach-Object {
                [ordered]@{ Name = $_.Name; Befehl = [string]$_.Value; Quelle = $k }
            }
        }
    }
    $ordner = foreach ($o in [Environment]::GetFolderPath('Startup'), [Environment]::GetFolderPath('CommonStartup')) {
        if ($o -and (Test-Path -LiteralPath $o)) {
            Get-ChildItem -LiteralPath $o -File -Force | Where-Object { $_.Name -ne 'desktop.ini' } | ForEach-Object { [ordered]@{ Name = $_.Name; Quelle = $o } }
        }
    }
    # Status "Deaktiviert" im Task-Manager liegt unter StartupApproved (erstes Byte ungerade = aus).
    $deaktiviert = @()
    foreach ($k in 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run',
                   'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run') {
        $p = Get-ItemProperty $k -ErrorAction SilentlyContinue
        if ($p) { $p.PSObject.Properties | Where-Object { $_.Name -notlike 'PS*' -and $_.Value -is [byte[]] -and ($_.Value[0] % 2) -eq 1 } | ForEach-Object { $deaktiviert += $_.Name } }
    }
    $aufgaben = Try-Get 'ScheduledTask' {
        @(Get-ScheduledTask | Where-Object { $_.TaskPath -notlike '\Microsoft\*' } | ForEach-Object {
            [ordered]@{ Name = $_.TaskName; Pfad = $_.TaskPath; Zustand = [string]$_.State; Autor = $_.Author
                        Aktion = (@($_.Actions | ForEach-Object { ('{0} {1}' -f $_.Execute, $_.Arguments).Trim() }) -join ' | ') }
        })
    }
    [ordered]@{
        Registry_Run = @($run)
        Autostartordner = @($ordner)
        Im_TaskManager_deaktiviert = $deaktiviert
        Geplante_Aufgaben_nicht_Microsoft = $aufgaben
    }
}

Invoke-Abschnitt 'Dienste' {
    $alle = @(Get-CimInstance Win32_Service)
    $nichtMs = @($alle | Where-Object {
        $_.PathName -and $_.PathName -notmatch '\\Windows\\(System32|SysWOW64|servicing|WinSxS)\\' -and $_.PathName -notmatch 'Windows Defender|Microsoft\\Windows Defender'
    } | Sort-Object Name | ForEach-Object {
        [ordered]@{ Name = $_.Name; Anzeige = $_.DisplayName; Start = $_.StartMode; Zustand = $_.State; Pfad = $_.PathName }
    })
    [ordered]@{
        Gesamt = $alle.Count
        Laufend = @($alle | Where-Object State -eq 'Running').Count
        Automatisch = @($alle | Where-Object StartMode -eq 'Auto').Count
        Hinweis = 'Liste enthaelt nur Dienste ausserhalb der Windows-Systemordner. Systemdienste werden nicht als Kandidaten betrachtet.'
        Nicht_Systemordner = $nichtMs
    }
}

Invoke-Abschnitt 'Prozesse' {
    $proc = @(Get-Process)
    [ordered]@{
        Anzahl = $proc.Count
        Top25_Arbeitsspeicher = @($proc | Sort-Object WorkingSet64 -Descending | Select-Object -First 25 | ForEach-Object {
            $pfad = $null; try { $pfad = $_.Path } catch {}
            [ordered]@{ Name = $_.ProcessName; RAM_MB = [math]::Round($_.WorkingSet64 / 1MB, 0); Pfad = $pfad }
        })
    }
}

Invoke-Abschnitt 'Entwicklung_und_KI' {
    $namen = 'py','python','python3','pip','git','claude','node','npm','npx','uv','code','ollama','docker','wsl','pwsh','java','adb','gh','winget','lmstudio','lms'
    $werkzeuge = foreach ($n in $namen) {
        $cmds = @(Get-Command $n -All -CommandType Application -ErrorAction SilentlyContinue)
        if ($cmds.Count -eq 0) { [ordered]@{ Name = $n; Gefunden = $false }; continue }
        $erster = $cmds[0].Source
        $arg = '--version'; if ($n -eq 'wsl') { $arg = '--status' }; if ($n -eq 'java') { $arg = '-version' }; if ($n -eq 'adb') { $arg = 'version' }
        [ordered]@{ Name = $n; Gefunden = $true; Pfad = $erster; WeiterePfade = @($cmds | Select-Object -Skip 1 | ForEach-Object Source); Version = (Get-WerkzeugVersion $erster $arg) }
    }
    $pyListe = $null
    $pyCmd = Get-Command py -ErrorAction SilentlyContinue
    if ($pyCmd) { $pyListe = Get-WerkzeugVersion $pyCmd.Source '-0p' }
    $ollamaModelle = $null
    $om = Join-Path $env:USERPROFILE '.ollama\models\manifests'
    if (Test-Path -LiteralPath $om) {
        $ollamaModelle = @(Get-ChildItem -LiteralPath $om -Recurse -File -Force -ErrorAction SilentlyContinue | ForEach-Object {
            $_.FullName.Substring($om.Length + 1)
        })
    }
    $claudeOrdner = @((Join-Path $env:USERPROFILE '.claude'), (Join-Path $env:APPDATA 'Claude'), (Join-Path $env:LOCALAPPDATA 'AnthropicClaude')) |
        Where-Object { Test-Path -LiteralPath $_ } | ForEach-Object { Get-OrdnerGroesse $_ }
    [ordered]@{
        Werkzeuge = @($werkzeuge)
        Python_Installationen_py_0p = $pyListe
        Ollama_Modelle = $ollamaModelle
        Claude_Ordner = @($claudeOrdner)
    }
}

Invoke-Abschnitt 'NOXARION_LARA_Dateien' {
    # Sucht nach Namen, die "noxarion", "lara" oder "arena" enthalten. Nur Namen, kein Dateiinhalt.
    # AppData\Local\Packages und Windows-/Programmordner werden ausgelassen.
    $muster = '(?i)noxarion|(^|[^a-z])lara([^a-z]|$)|lara[-_ ]?ai|arena[-_ ]?10'
    $treffer = New-Object System.Collections.Generic.List[object]
    $wurzeln = New-Object System.Collections.Generic.List[string]
    $wurzeln.Add($env:USERPROFILE)
    Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | ForEach-Object { $wurzeln.Add($_.DeviceID + '\') }
    $oberste = '(?i)^(Windows|Program Files|Program Files \(x86\)|ProgramData|\$Recycle\.Bin|System Volume Information|Recovery|Users)$'
    $ausschluss = '(?i)\\AppData\\Local\\Packages(\\|$)|\\node_modules(\\|$)|\\\.git(\\|$)|\\\.venv(\\|$)'
    $maxTiefe = 7; $maxTreffer = 500
    foreach ($w in $wurzeln) {
        $stapel = New-Object System.Collections.Generic.Stack[object]
        $stapel.Push(@($w, 0))
        while ($stapel.Count -gt 0 -and $treffer.Count -lt $maxTreffer) {
            $e = $stapel.Pop(); $pfad = $e[0]; $tiefe = $e[1]
            try {
                foreach ($x in (New-Object System.IO.DirectoryInfo($pfad)).EnumerateFileSystemInfos()) {
                    if ($x.Attributes -band [IO.FileAttributes]::ReparsePoint) { continue }
                    if ($x.Name -match $muster) {
                        $istOrdner = $x -is [IO.DirectoryInfo]
                        $treffer.Add([ordered]@{ Pfad = $x.FullName; Art = $(if ($istOrdner) { 'Ordner' } else { 'Datei' }); Geaendert = $x.LastWriteTime.ToString('yyyy-MM-dd') })
                    }
                    if ($x -is [IO.DirectoryInfo] -and $tiefe -lt $maxTiefe -and $x.FullName -notmatch $ausschluss -and -not ($x.Parent.Parent -eq $null -and $x.Name -match $oberste)) { $stapel.Push(@($x.FullName, ($tiefe + 1))) }
                }
            } catch { }
        }
    }
    $eindeutig = @($treffer | Sort-Object { $_.Pfad } -Unique)
    [ordered]@{ Suchmuster = $muster; MaxTiefe = $maxTiefe; Anzahl = $eindeutig.Count; Begrenzt_auf = $maxTreffer; Treffer = $eindeutig }
}

Invoke-Abschnitt 'Netzwerk' {
    $adapter = Try-Get 'NetAdapter' {
        @(Get-NetAdapter | ForEach-Object {
            [ordered]@{ Name = $_.Name; Beschreibung = $_.InterfaceDescription; Status = [string]$_.Status; Geschwindigkeit = $_.LinkSpeed; Treiber = $_.DriverVersionString }
        })
    }
    $ip = Try-Get 'NetIPConfiguration' {
        @(Get-NetIPConfiguration | Where-Object { $_.IPv4Address } | ForEach-Object {
            [ordered]@{ Adapter = $_.InterfaceAlias; IPv4 = @($_.IPv4Address | ForEach-Object IPAddress); Gateway = @($_.IPv4DefaultGateway | ForEach-Object NextHop); DNS = @($_.DNSServer | Where-Object AddressFamily -eq 2 | ForEach-Object { $_.ServerAddresses }) }
        })
    }
    $wlan = Try-Get 'WLAN' { $t = (netsh wlan show interfaces) -join "`n"; ($t -replace '(?im)^\s*(BSSID|Physische Adresse|Physical address).*$', '').Trim() }
    $dns = Try-Get 'DNS-Test' { [bool]([System.Net.Dns]::GetHostAddresses('www.microsoft.com').Count -gt 0) }
    $ping = Try-Get 'Ping' { [bool](Test-Connection -ComputerName 1.1.1.1 -Count 1 -Quiet) }
    $vpn = Try-Get 'VPN' { @(Get-VpnConnection -ErrorAction SilentlyContinue | ForEach-Object { [ordered]@{ Name = $_.Name; Status = [string]$_.ConnectionStatus } }) }
    $vpnAdapter = @(@($adapter) | Where-Object { $_ -is [System.Collections.IDictionary] -and $_.Beschreibung -match '(?i)wireguard|tailscale|openvpn|tap-windows|wintun|zerotier|nordlynx|vpn' })
    [ordered]@{ Adapter = $adapter; IP = $ip; WLAN = $wlan; Internet_DNS_ok = $dns; Internet_Ping_1111_ok = $ping; Windows_VPN = $vpn; VPN_aehnliche_Adapter = $vpnAdapter }
}

Invoke-Abschnitt 'Geraete' {
    $klasse = { param($k) Try-Get ("PnP " + $k) { @(Get-PnpDevice -Class $k -PresentOnly -ErrorAction SilentlyContinue | ForEach-Object { [ordered]@{ Name = $_.FriendlyName; Status = [string]$_.Status } }) } }
    $probleme = Try-Get 'PnP Probleme' {
        @(Get-PnpDevice -PresentOnly | Where-Object { $_.Status -ne 'OK' } | ForEach-Object {
            [ordered]@{ Name = $_.FriendlyName; Klasse = $_.Class; Status = [string]$_.Status; Problemcode = [string]$_.Problem; InstanceId = $_.InstanceId }
        })
    }
    $audio = @(Get-CimInstance Win32_SoundDevice | ForEach-Object { [ordered]@{ Name = $_.Name; Status = $_.Status } })
    $bt = Try-Get 'Bluetooth-Dienst' { $s = Get-Service bthserv -ErrorAction Stop; [ordered]@{ Dienst = [string]$s.Status; Start = [string]$s.StartType } }
    [ordered]@{
        Bluetooth = (& $klasse 'Bluetooth'); Bluetooth_Dienst = $bt
        USB_Controller = (& $klasse 'USB')
        Audio = $audio
        Monitore = (& $klasse 'Monitor')
        Geraete_mit_Problem = $probleme
    }
}

Invoke-Abschnitt 'Sicherheit_und_Wiederherstellung' {
    $def = Try-Get 'Defender' {
        $m = Get-MpComputerStatus
        [ordered]@{ Echtzeitschutz = $m.RealTimeProtectionEnabled; Antivirus = $m.AntivirusEnabled; Signaturen_Alter_Tage = $m.AntivirusSignatureAge; Letzter_Schnellscan = $(if ($m.QuickScanEndTime) { $m.QuickScanEndTime.ToString('yyyy-MM-dd') } else { $null }) }
    }
    $av = Try-Get 'SecurityCenter' { @(Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntiVirusProduct | ForEach-Object displayName) }
    $fw = Try-Get 'Firewall' { @(Get-NetFirewallProfile | ForEach-Object { [ordered]@{ Profil = $_.Name; Aktiv = [string]$_.Enabled } }) }
    $rp = $(if ($script:IstAdmin) {
        Try-Get 'Wiederherstellungspunkte' { @(Get-ComputerRestorePoint | ForEach-Object { [ordered]@{ Nr = $_.SequenceNumber; Beschreibung = $_.Description; Datum = $_.ConvertToDateTime($_.CreationTime).ToString('yyyy-MM-dd HH:mm') } }) }
    } else { 'Nur mit Adminrechten lesbar - Skript bei Bedarf als Administrator starten' })
    $srDeaktiviert = Try-Get 'Systemschutz' {
        $p = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore' -ErrorAction Stop
        if ($p.PSObject.Properties.Name -contains 'DisableSR') { [bool]$p.DisableSR } else { $false }
    }
    $bitlocker = Try-Get 'BitLocker' { @(Get-BitLockerVolume -ErrorAction Stop | ForEach-Object { [ordered]@{ Laufwerk = $_.MountPoint; Schutz = [string]$_.ProtectionStatus } }) }
    $fileHistory = Test-Path (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\FileHistory\Configuration')
    [ordered]@{
        Defender = $def; Virenschutz_lt_SecurityCenter = $av; Firewall = $fw
        Systemschutz_per_Richtlinie_deaktiviert = $srDeaktiviert; Wiederherstellungspunkte = $rp
        BitLocker = $bitlocker; Dateiversionsverlauf_konfiguriert = $fileHistory
        Fernzugriff_RDP_aktiv = (Try-Get 'RDP' { (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' -ErrorAction Stop).fDenyTSConnections -eq 0 })
    }
}

# ---------------------------------------------------------------- Ausgabe

$script:Bericht['Fehlerprotokoll'] = @($script:Fehler)

if (-not $Ausgabeordner) {
    $Ausgabeordner = Join-Path ([Environment]::GetFolderPath('Desktop')) ('NOXARION-Bestandsaufnahme\' + (Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'))
}
New-Item -ItemType Directory -Path $Ausgabeordner -Force | Out-Null

$json = $script:Bericht | ConvertTo-Json -Depth 8

function Format-Wert {
    param($v)
    if ($null -eq $v) { return '-' }
    if ($v -is [System.Collections.IDictionary]) { return (($v.Keys | ForEach-Object { '{0}: {1}' -f $_, (Format-Wert $v[$_]) }) -join '; ') }
    if ($v -is [System.Collections.IEnumerable] -and $v -isnot [string]) { return ((@($v) | ForEach-Object { Format-Wert $_ }) -join ', ') }
    return ([string]$v -replace '\|', '/' -replace '\r?\n', ' ')
}

$md = New-Object System.Text.StringBuilder
[void]$md.AppendLine('# NOXARION - PC-Bestandsaufnahme (Phase 1)')
[void]$md.AppendLine()
[void]$md.AppendLine('Rein lesend erstellt. Es wurde nichts geloescht, verschoben, deinstalliert oder umkonfiguriert.')
[void]$md.AppendLine('Vor dem Weitergeben bitte pruefen: Der Bericht enthaelt Programmliste, Pfade und lokale IP-Adressen.')
[void]$md.AppendLine()
foreach ($abschnitt in $script:Bericht.Keys) {
    [void]$md.AppendLine("## $abschnitt"); [void]$md.AppendLine()
    $inhalt = $script:Bericht[$abschnitt]
    if ($inhalt -is [System.Collections.IDictionary]) {
        foreach ($k in $inhalt.Keys) {
            $v = $inhalt[$k]
            $liste = @($v)
            if ($v -isnot [string] -and $liste.Count -gt 0 -and $liste[0] -is [System.Collections.IDictionary]) {
                [void]$md.AppendLine("### $k ($($liste.Count))"); [void]$md.AppendLine()
                $spalten = @($liste[0].Keys)
                [void]$md.AppendLine('| ' + ($spalten -join ' | ') + ' |')
                [void]$md.AppendLine('|' + (($spalten | ForEach-Object { '---' }) -join '|') + '|')
                foreach ($zeile in $liste) {
                    if ($zeile -is [System.Collections.IDictionary]) { [void]$md.AppendLine('| ' + (($spalten | ForEach-Object { Format-Wert $zeile[$_] }) -join ' | ') + ' |') }
                }
                [void]$md.AppendLine()
            } else {
                [void]$md.AppendLine("- **$k**: $(Format-Wert $v)")
            }
        }
    } else {
        foreach ($z in @($inhalt)) { [void]$md.AppendLine("- $(Format-Wert $z)") }
    }
    [void]$md.AppendLine()
}
$mdText = $md.ToString()

if ($Anonymisieren) {
    foreach ($ersetzung in @(@($env:USERNAME, '<BENUTZER>'), @($env:COMPUTERNAME, '<PC>'))) {
        if ($ersetzung[0]) {
            $re = [regex]::Escape($ersetzung[0])
            $json = [regex]::Replace($json, $re, $ersetzung[1], 'IgnoreCase')
            $mdText = [regex]::Replace($mdText, $re, $ersetzung[1], 'IgnoreCase')
        }
    }
}

$utf8 = New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllText((Join-Path $Ausgabeordner 'bericht.json'), $json, $utf8)
[IO.File]::WriteAllText((Join-Path $Ausgabeordner 'bericht.md'), $mdText, $utf8)
[IO.File]::WriteAllLines((Join-Path $Ausgabeordner 'fehler.log'), [string[]]@($script:Fehler), $utf8)

Write-Host ''
Write-Host 'Fertig. Bericht gespeichert in:' -ForegroundColor Cyan
Write-Host "  $Ausgabeordner"
Write-Host ("Abschnitte mit Problemen: {0} (Details in fehler.log)" -f $script:Fehler.Count)
