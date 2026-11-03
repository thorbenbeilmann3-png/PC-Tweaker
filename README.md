# PC-Tweaker

Windows-PC-Diagnose und Wartung mit optionaler lokaler Ollama-Anbindung.

## Aktueller Stand

Dies ist das Grundgerüst (Version 0.1.0), noch keine fertige Tweaker-Suite. Enthalten sind eine erste Desktop-Oberfläche, eine rein lesende Systemübersicht sowie Start- und Build-Skripte. Update-Verwaltung, Geräte-/Treiberdiagnose und Ollama-Steuerung sind als nächste Ausbaustufen vorgesehen.

**Sicherheitsprinzip:** Keine Treiber- oder Systemänderung ohne ausdrückliche Bestätigung. Unbekannte Treiberquellen werden nicht verwendet. Die App soll ohne Ollama nutzbar bleiben.

## Voraussetzungen

- Windows 10/11 (die tatsächliche Kompatibilität wird noch getestet)
- Python 3.11 oder neuer
- Internetverbindung für die erstmalige Installation der Python-Abhängigkeiten

## Starten

1. Repository herunterladen: **Code → Download ZIP**, oder mit Git klonen.
2. ZIP entpacken.
3. `STARTEN.bat` doppelklicken.

Das Skript erstellt eine lokale virtuelle Python-Umgebung und installiert die Abhängigkeiten. Es installiert Python nicht automatisch. Falls der Python-Launcher fehlt, öffnet es die offizielle Download-Seite.

## EXE bauen

`BAUEN_EXE.bat` doppelklicken. Die EXE-Ausgabe wird mit PyInstaller unter `dist/PC-Tweaker/` erstellt. Der Build muss auf Windows ausgeführt und dort getestet werden.

## Tests

In einer aktivierten virtuellen Umgebung:

```powershell
python -m pip install -e ".[dev]"
python -m pytest -q
```

## Roadmap

- [ ] Windows-Update- und winget-Status mit Bestätigung vor Änderungen
- [ ] Geräte-Manager-Diagnose inklusive Problemcodes und Hardware-IDs
- [ ] Treiberprüfung über verifizierte Herstellerquellen, keine blinden Treiber-Updater
- [ ] Wiederherstellungspunkte und unterstützter Rollback
- [ ] Optionale lokale Ollama-Anbindung
- [ ] Windows-CI, GUI-Test und reproduzierbarer EXE-Test
- [ ] Installationspaket, Symbol und Startmenü-Verknüpfung


## Geplante Funktion: Ordner-Inhalt bereinigen

Der Nutzer soll einen beliebigen Startordner auswählen können. PC-Tweaker durchsucht diesen Ordner anschließend rekursiv einschließlich aller Unterordner und zeigt den vollständigen Inhalt in einer Baumansicht mit Kontrollkästchen an.

- **Angehakt = behalten:** Dateien und Ordner mit gesetztem Haken werden ausdrücklich geschützt und nicht gelöscht.
- **Nicht angehakt = zum Löschen vorgemerkt:** Alle nicht geschützten Dateien und Ordner innerhalb des ausgewählten Startordners werden zur Bereinigung vorgemerkt.
- Wird ein Unterordner angehakt, bleibt dieser einschließlich seines gesamten Inhalts erhalten.
- Wird nur eine einzelne Datei angehakt, bleibt diese Datei erhalten; andere Dateien im selben Ordner dürfen gelöscht werden.
- Vor dem Ausführen gibt es eine Vorschau mit Anzahl und Größe der betroffenen Dateien sowie der geschützten Elemente. Der Nutzer muss die Aktion ausdrücklich bestätigen.
- Standardmäßig werden Elemente in den Windows-Papierkorb verschoben, nicht unwiderruflich gelöscht. Eine dauerhafte Löschung darf nur als gesonderte, deutlich gewarnte Option angeboten werden.
- Laufwerk-Wurzeln, Windows-Systemordner und Programmordner werden standardmäßig blockiert. Verknüpfungen/Junctions dürfen nicht verfolgt werden, damit keine Inhalte außerhalb des gewählten Startordners betroffen sind.
- Bei Fehlern oder gesperrten Dateien wird der Vorgang sicher angehalten bzw. übersprungen und jeder Fehlschlag protokolliert. Geschützte Elemente dürfen niemals aufgrund eines Fehlers versehentlich mitgelöscht werden.
- Vor dem Löschen wird die Auswahl erneut geprüft; Änderungen am Ordnerinhalt seit der Vorschau müssen angezeigt werden.

## Status der Prüfung

Noch nicht auf einem echten Windows-PC ausgeführt. Es liegt daher derzeit **kein bestätigter Windows-Laufzeittest und keine geprüfte EXE** vor.
