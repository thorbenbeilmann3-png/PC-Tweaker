"""Read-only system information helpers."""
import platform
import psutil


def collect_system_info() -> dict[str, str]:
    """Return basic system facts without changing the machine."""
    memory_gb = psutil.virtual_memory().total / (1024 ** 3)
    return {
        "Betriebssystem": platform.platform(),
        "Windows-Version": platform.version() if platform.system() == "Windows" else "Nicht Windows",
        "Architektur": platform.machine(),
        "Prozessor": platform.processor() or "Nicht ermittelt",
        "Arbeitsspeicher": f"{memory_gb:.1f} GB",
        "Python": platform.python_version(),
    }
