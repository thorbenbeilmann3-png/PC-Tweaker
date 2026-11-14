"""Lesender Planer zum Aufteilen einer Festplatte (z. B. 1 TB in Windows/KI/NAS).

Dieses Modul aendert NICHTS am System. Es liest nur das aktuelle Layout aus
und rechnet einen Groessen-Vorschlag. Echte Aenderungen erfolgen von Hand in
der Datentraegerverwaltung (diskmgmt.msc) - nur nach Backup.
"""
from __future__ import annotations

import argparse
import sys

LABELS = ["Windows", "KI", "NAS", "Daten", "Backup"]
GB = 1_000_000_000


def plan_split(total_bytes: int, targets_gb: list[float], labels: list[str] | None = None) -> dict:
    """Rechnet einen Partitions-Vorschlag. Wirft ValueError, wenn die Ziele nicht passen."""
    labels = labels or LABELS
    if total_bytes <= 0:
        raise ValueError("Gesamtgroesse muss positiv sein")
    if not targets_gb:
        raise ValueError("mindestens eine Zielgroesse angeben")
    parts: list[dict] = []
    used = 0
    for i, gb in enumerate(targets_gb):
        if gb <= 0:
            raise ValueError("Zielgroessen muessen positiv sein")
        size = int(gb * GB)
        used += size
        if used > total_bytes:
            raise ValueError(
                f"Ziele gesamt {used / GB:.0f} GB passen nicht auf {total_bytes / GB:.0f} GB nutzbar"
            )
        label = labels[i] if i < len(labels) else f"Teil {i + 1}"
        parts.append({"label": label, "gb": gb, "size_bytes": size})
    return {"total_bytes": total_bytes, "parts": parts, "rest_bytes": total_bytes - used}


def collect_disk_layout() -> list[dict]:
    """Liest alle Partitionen und deren Belegung (nur lesend)."""
    import psutil  # lazy import: erst zur Laufzeit noetig

    rows = []
    for p in psutil.disk_partitions(all=True):
        try:
            u = psutil.disk_usage(p.mountpoint)
            total, used, free = round(u.total / GB, 1), round(u.used / GB, 1), round(u.free / GB, 1)
        except (PermissionError, OSError):
            total = used = free = None
        rows.append(
            {
                "device": p.device,
                "mountpoint": p.mountpoint,
                "fstype": p.fstype,
                "total_gb": total,
                "used_gb": used,
                "free_gb": free,
            }
        )
    return rows


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(
        description="Nur lesend: Plattenlayout anzeigen und Partitions-Split vorschlagen. Aendert nichts am System!"
    )
    ap.add_argument(
        "--sizes",
        default="400,200,400",
        help="Zielgroessen in GB, kommagetrennt (Standard: 400,200,400 = Windows, KI, NAS)",
    )
    args = ap.parse_args(argv)

    print("PC-Tweaker Partition-Planer (LESEND - aendert nichts)")
    print("Vor jeder echten Aenderung: Backup + Wiederherstellungspunkt erstellen!\n")
    rows = collect_disk_layout()
    print("Aktuelle Partitionen:")
    for r in rows:
        print(
            f"  {r['device'] or '-':<12} {r['mountpoint'] or '-':<8} {r['fstype'] or '-':<8}"
            f" gesamt={r['total_gb']} GB  belegt={r['used_gb']} GB  frei={r['free_gb']} GB"
        )

    targets = [float(x) for x in args.sizes.split(",") if x.strip()]
    biggest = max((r["total_gb"] or 0) for r in rows) if rows else 0
    if biggest:
        # ca. 2 % Formatierungs-Overhead abziehen -> real nutzbar
        usable_bytes = int(biggest * GB * 0.98)
        try:
            plan = plan_split(usable_bytes, targets)
            print(f"\nVorschlag fuer groesste Platte (~{biggest:.0f} GB brutto, ~{usable_bytes / GB:.0f} GB nutzbar):")
            for p in plan["parts"]:
                print(f"  {p['label']:<10} {p['gb']:.0f} GB")
            print(f"  Rest/Puffer: {plan['rest_bytes'] / GB:.1f} GB")
            print("\nUmsetzung von Hand: siehe docs/partitionieren.md (Backup zuerst!).")
        except ValueError as e:
            print(f"\nVorschlag nicht moeglich: {e}")
            print("Tipp: 1 TB = ca. 931 GiB nutzbar. 400+200+400 GB (dezimal) passt da knapp nicht;")
            print("z. B. --sizes 380,180,360 oder Puffer einplanen.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
