from pc_tweaker.system_info import collect_system_info


def test_system_info_returns_expected_fields():
    info = collect_system_info()
    assert "Betriebssystem" in info
    assert "Architektur" in info
    assert "Arbeitsspeicher" in info
