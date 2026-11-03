"""PC-Tweaker desktop application entry point."""
import sys
from PySide6.QtWidgets import QApplication, QLabel, QMainWindow, QTabWidget, QWidget, QVBoxLayout, QFormLayout
from .system_info import collect_system_info


class MainWindow(QMainWindow):
    def __init__(self) -> None:
        super().__init__()
        self.setWindowTitle("PC-Tweaker")
        self.resize(1000, 680)
        tabs = QTabWidget()
        overview = QWidget()
        layout = QVBoxLayout(overview)
        layout.addWidget(QLabel("PC-Tweaker – Systemübersicht"))
        form = QFormLayout()
        for key, value in collect_system_info().items():
            form.addRow(f"{key}:", QLabel(value))
        layout.addLayout(form)
        tabs.addTab(overview, "Übersicht")
        for title, note in [
            ("Updates", "Update-Prüfung folgt; Änderungen nur nach ausdrücklicher Bestätigung."),
            ("Geräte & Treiber", "Diagnose und Fehlercodes folgen. Keine automatische Treiberinstallation."),
            ("Wiederherstellung", "Sicherungs- und Rücksetzfunktionen folgen."),
            ("Ollama", "Optionale lokale KI-Anbindung folgt. Die App funktioniert auch ohne Ollama."),
        ]:
            page = QWidget(); page_layout = QVBoxLayout(page); page_layout.addWidget(QLabel(note)); tabs.addTab(page, title)
        self.setCentralWidget(tabs)


def main() -> int:
    app = QApplication(sys.argv)
    window = MainWindow(); window.show()
    return app.exec()


if __name__ == "__main__":
    raise SystemExit(main())
