"""Static safety checks for tools/Bestandsaufnahme.ps1.

The inventory script must stay strictly read-only. These tests cannot run the
script (it needs Windows), but they block accidental use of modifying cmdlets.
"""
import re
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "tools" / "Bestandsaufnahme.ps1"

FORBIDDEN = [
    r"Remove-\w+", r"Uninstall-\w+", r"Stop-\w+", r"Restart-\w+", r"Disable-\w+",
    r"Enable-\w+", r"Set-(?!StrictMode)\w+", r"Clear-\w+", r"Move-Item", r"Rename-Item",
    r"Copy-Item", r"Start-Service", r"Install-\w+", r"Register-\w+", r"Unregister-\w+",
    r"New-ItemProperty", r"Checkpoint-Computer", r"Format-Volume", r"Invoke-WebRequest",
    r"Invoke-RestMethod", r"\bsc(\.exe)?\s+(config|delete|stop)", r"\breg(\.exe)?\s+(add|delete)",
    r"\bdel\s", r"\bnetsh\s+(?!wlan\s+show)", r"\.Delete\(", r"\.Kill\(\)",
]


def _code() -> str:
    text = SCRIPT.read_text(encoding="utf-8-sig")
    text = re.sub(r"<#.*?#>", "", text, flags=re.S)          # block comments
    return "\n".join(line.split("#", 1)[0] if line.lstrip().startswith("#") else line
                     for line in text.splitlines())


def test_script_has_utf8_bom_for_windows_powershell_51():
    assert SCRIPT.read_bytes()[:3] == b"\xef\xbb\xbf"


def test_no_modifying_commands():
    code = _code()
    hits = []
    for pattern in FORBIDDEN:
        for m in re.finditer(pattern, code, flags=re.I):
            line = code[: m.start()].count("\n") + 1
            hits.append(f"{m.group(0)} (Zeile {line})")
    # Only allowed process kill: the version-probe timeout of a process the script started itself.
    hits = [h for h in hits if not h.startswith(".Kill()")]
    assert hits == [], f"Modifying commands found: {hits}"


def test_kill_only_used_for_own_timeout():
    code = _code()
    assert code.count(".Kill()") == 1
    assert "WaitForExit(15000)" in code


def test_only_writes_into_report_folder():
    code = _code()
    assert len(re.findall(r"New-Item\b", code)) == 1
    assert "New-Item -ItemType Directory -Path $Ausgabeordner" in code
    writes = re.findall(r"\[IO\.File\]::Write\w+\(\(Join-Path \$Ausgabeordner", code)
    assert len(writes) == 3
    assert len(re.findall(r"\[IO\.File\]::Write", code)) == 3


def test_windowsapps_aliases_are_not_executed():
    assert "*\\WindowsApps\\*" in _code()
