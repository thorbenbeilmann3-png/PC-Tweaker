# Festplatte teilen – sicherer Ablauf (z. B. 1 TB in Windows 400 / KI 200 / NAS 400 GB)

**Grundsatz: Partitionieren kann Daten zerstören. Erst Backup, dann ändern.**

## 0. Planer (nur lesend, aendert nichts)

Auf dem PC aus dem Repo starten:

```bat
python -m pc_tweaker.partition_plan --sizes 400,200,400
```

zeigt das aktuelle Layout und rechnet, ob die Wuenschgroessen passen.
Realistisch: 1 TB = ca. 931 GiB nutzbar. 400+200+400 GB (dezimal = 1000 GB) passt
dadurch knapp nicht – nimm z. B. `--sizes 380,180,360` oder lass Puffer.

## 1. Vorbereiten

1. **Backup** aller wichtigen Daten auf externe Platte/Cloud + Wiederherstellungspunkt
   (`Win + R` → `rstrui.exe`).
2. **BitLocker pausieren** (Systemsteuerung → BitLocker), falls aktiv.
3. Platte **defragmentieren/optimieren** (Laufwerke optimieren), damit Windows
   das Volume weit genug verkleinern kann.
4. Falls „Volume verkleinern“ zu wenig anbietet: Ruhezustand und Auslagerungsdatei
   temporaer aus (`powercfg /hibernate off`, pagefile auf anderes Laufwerk legen),
   danach wieder aktivieren.

## 2. Aufteilen (Datentraegerverwaltung)

1. `Win + R` → `diskmgmt.msc` → richtige Platte identifizieren (nicht die falsche!).
2. Rechtsklick auf das Windows-Volume (meist C:) → **„Volume verkleinern …“** →
   so viel verkleinern, dass ca. **400 GB** fuer Windows bleiben (bei 1 TB Platte
   also ca. **600 GB = 614400 MB** verkleinern; Rest/Puffer siehe Planer).
3. Im **nicht zugeordneten** Bereich rechtsklicken → **„Neues einfaches Volume“**:
   - **KI**: 200 GB (204800 MB), NTFS, Laufwerksbuchstabe z. B. `D:`, Name „KI“
   - **NAS**: 400 GB (409600 MB), NTFS, z. B. `E:`, Name „NAS“
   - Windows behaelt den Rest (~400 GB).
4. Nie waehrend des Vorgangs abbrechen oder den PC ausschalten.

## 3. Anschliessen einrichten

- **KI**: Ollama-Modelle auf das KI-Volume legen über Umgebungsvariable
  `OLLAMA_MODELS` = `D:\KI\modelle` (Systemumgebungsvariablen), dann Modelle neu laden.
  LARA/PC-Hub erreichbar wie gehabt unter `127.0.0.1:11434`.
- **NAS**: Ordner auf dem NAS-Volume anlegen (z. B. `E:\Freigaben`) und per SMB
  im lokalen Netz freigeben – nur LAN, kein oeffentlicher Zugriff.
- **Windows**: bleibt auf C:, nichts weiter noetig.

## 4. Pruefen

- `diskmgmt.msc`: drei Volumes mit den gewuenschten Groessen, alles NTFS.
- Planer erneut laufen lassen: `python -m pc_tweaker.partition_plan` zeigt die neue Aufteilung.
- Backup erst loeschen, wenn alles laeuft.
