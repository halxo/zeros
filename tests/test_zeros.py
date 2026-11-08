import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "zeros_py"))
from zeros import detect, kernel, release, updater

def test_cpu_parse():
    m, f = detect.parse_cpuinfo("model name\t: Foo CPU\nflags\t\t: fpu sse sse2 avx avx2 aes\n")
    assert m == "Foo CPU" and f == ["aes", "avx", "avx2", "sse", "sse2"]

def test_lspci():
    t = "00:02.0 VGA compatible controller [0300]: Intel [8086:46a6]\n01:00.0 3D controller [0302]: NVIDIA [10de:2504]\n02:00.0 Non-Volatile memory controller [0108]: Samsung [144d:a809]\n03:00.0 Network controller [0280]: Intel Corporation Wi-Fi 6 AX200 [8086:2723]"
    cards, nvme, wifi = detect.parse_lspci(t)
    assert cards == ["intel", "nvidia"]
    assert nvme is True
    assert wifi is True

def test_cache_key_stable_and_hw_specific():
    a = detect.Profile(march="znver3", cpu_flags=["avx2"])
    b = detect.Profile(march="znver3", cpu_flags=["avx2"], mem_mb=999)
    c = detect.Profile(march="skylake", cpu_flags=["avx2"])
    assert a.cache_key() == b.cache_key() != c.cache_key()

def test_make_conf_bounds_jobs_by_ram():
    p = detect.Profile(cores=16, mem_mb=4096, march="x")
    assert 'MAKEOPTS="-j2"' in detect.make_conf(p)

def test_kernel_latest_skips_rc():
    import json
    data = json.dumps({"latest_stable": {"version": "6.99.1"}}).encode()
    assert kernel.latest_stable(lambda: data) == "6.99.1"
    assert kernel.valid_version("6.99.1") and not kernel.valid_version("6.99-rc1")

def test_release_names():
    assert release.milestone_name() == "Nova"
    assert release.milestone_name(["Nova"]) == "Aurora"
    assert release.rolling_tag().startswith("rolling-")

def test_updater_pending_then_ok(tmp_path, monkeypatch):
    monkeypatch.setattr(updater, "STATE", str(tmp_path / "s.json"))
    updater.save({"pending": "snap1", "last_good": None})
    assert updater.boot_ok()["last_good"] == "snap1"
    assert updater.load()["pending"] is None
