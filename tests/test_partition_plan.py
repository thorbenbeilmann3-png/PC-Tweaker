import pytest

from pc_tweaker.partition_plan import plan_split

GIB = 1024**3


def test_plan_split_labels_and_sizes():
    plan = plan_split(1_100_000_000_000, [400, 200, 400])
    assert [p["label"] for p in plan["parts"]] == ["Windows", "KI", "NAS"]
    assert plan["parts"][0]["size_bytes"] == 400 * 1_000_000_000
    assert plan["rest_bytes"] == 1_100_000_000_000 - 1_000_000_000_000


def test_plan_split_1tb_realistisch_passt_knapp_nicht():
    # 1 TB brutto = 931,32 GiB = ca. 999,65 GB dezimal -> 400+200+400 GB (1000 GB) passt nicht
    total = int(931.32 * GIB)
    with pytest.raises(ValueError):
        plan_split(total, [400, 200, 400])


def test_plan_split_mit_puffer_passt():
    total = int(931.32 * GIB)
    plan = plan_split(total, [380, 180, 360])
    assert plan["rest_bytes"] >= 0
    assert sum(p["size_bytes"] for p in plan["parts"]) + plan["rest_bytes"] == total


def test_plan_split_ungueltige_werte():
    with pytest.raises(ValueError):
        plan_split(0, [400])
    with pytest.raises(ValueError):
        plan_split(1_000_000_000_000, [])
    with pytest.raises(ValueError):
        plan_split(1_000_000_000_000, [400, -5])
