# NOXARION – Einrichtungsprotokoll PC Thorben

Stand: 2026-11-07. Grundregel: keine ungeprüften Löschungen, keine ungesicherten Systemänderungen, keine erfundenen Testergebnisse. Nicht getestete Funktionen bleiben **OFFEN**.

## Ausgangslage (Fakten)

- Die bisherige Arbeit lief in einer Cloud-Umgebung (Linux-Container). **Zum PC Thorben besteht keine Verbindung.** Remote Control war nicht verbunden; es wurden keine freigegebenen Ordner gefunden.
- Deshalb wurde auf dem PC selbst noch **nichts** erfasst, gelöscht oder geändert.
- PC-Tweaker 0.1.0 ist ein Grundgerüst und wurde noch nie auf Windows ausgeführt.
- LARA-AI-HUB ist eine Android-App mit Chat-Oberfläche. PC-Fernsteuerung, Windows-Agent und ARENA sind laut README noch nicht umgesetzt.

## Phase 1 – Bestandsaufnahme

Werkzeug: `BESTANDSAUFNAHME.bat` → `tools/Bestandsaufnahme.ps1`

- Rein lesend. Schreibt nur einen neuen Berichtsordner auf den Desktop: `NOXARION-Bestandsaufnahme\<Zeitstempel>\bericht.md`, `bericht.json`, `fehler.log`.
- Erfasst die Punkte 1–8 aus dem Protokoll: Windows/Build, CPU/RAM/GPU/VRAM/Datenträger (inkl. Zustand), Belegung von Laufwerken und Ordnern, Programme (Desktop + Store), Autostart/geplante Aufgaben/Fremddienste/Top-Prozesse, Python/Git/Claude/Node/Ollama usw., NOXARION/LARA-Dateinamen, Netzwerk/WLAN/VPN, Bluetooth/USB/Audio/Monitore, Geräte mit Problemcode, Defender/Firewall/Systemschutz/RDP.
- Benutzer- und Computername werden im Bericht durch `<BENUTZER>`/`<PC>` ersetzt. Lokale IPs und die Programmliste stehen trotzdem drin, deshalb vor dem Weitergeben ansehen.
- Ohne Adminrechte fehlen Wiederherstellungspunkte und BitLocker. Das wird im Bericht vermerkt.
- Geprüft: statische Tests in `tests/test_bestandsaufnahme_readonly.py` (keine verändernden Befehle, UTF-8-BOM, Schreiben nur in den Berichtsordner) und Klammerbilanz.
- **Nicht geprüft:** Ein echter Lauf unter Windows steht noch aus. PowerShell gab es in der Cloud-Umgebung nicht.

**Status: OFFEN** – erledigt erst, wenn der Bericht vom PC vorliegt.

## Phasen 2–10 – Abhängigkeiten und Sicherheitsentscheidungen

| Phase | Status | Voraussetzung / Entscheidung |
|---|---|---|
| 2 Aufräumen | OFFEN | Kandidatenliste wird **aus dem Phase-1-Bericht** erstellt. Pro Eintrag: Zweck, Größe, Folgen und dann JA/NEIN. Geschützt bleiben Systemdateien, Wiederherstellung, Netzwerk, Defender, Firewall, Treiber, Python/Git/Claude, NOXARION/LARA. |
| 3 Ordner sortieren | OFFEN | Zuerst nur ein Verschiebeplan als Probelauf mit Protokoll für die Rücksortierung. Duplikate per SHA-256 erkennen. Unklare Dateien bleiben liegen. |
| 4 Sicherung | OFFEN | Muss vor Phase 2/3-Ausführung stehen: Wiederherstellungspunkt (Admin), externe Sicherung von NOXARION/LARA, Rücksicherung testen. |
| 5 Maus/Tastatur-Steuerung | OFFEN | Möglicher Weg: Claude-Desktop-App mit Computer Use auf dem PC oder ein eigener lokaler Agent. Not-Aus und Vorrang für deine eigenen Eingaben sind Pflicht. |
| 6 Handy-Steuerung | OFFEN | Nur über ein authentifiziertes, verschlüsseltes privates Netz (z. B. Tailscale/WireGuard) oder Remote Control. **Keine Portfreigabe im Router.** LARA spricht derzeit unverschlüsseltes HTTP und hat keine Anmeldung, darf also nicht ins Internet. |
| 7 Online-Überwachung | OFFEN | Baut auf Phase 6 auf. Entprellung gegen doppelte Meldungen ist nötig. |
| 8 LARA ↔ NOXARION | OFFEN | Im Code wurde noch kein NOXARION-Core gefunden. Der Phase-1-Bericht zeigt, ob lokal Dateien vorhanden sind. |
| 9 ARENA 10 | OFFEN | Braucht API-Zugänge zu den Modellen. Welche zehn Modelle tatsächlich verfügbar sind, ist offen. |
| 10 Abschlussprüfung | OFFEN | Alle Punkte erst nach einem echten Test auf dem PC abhaken. |
