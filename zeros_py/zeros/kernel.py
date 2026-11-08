"""Fetch newest stable kernel version and build a hardware-tailored config."""
import json, re, subprocess, urllib.request

RELEASES = "https://www.kernel.org/releases.json"


def latest_stable(fetch=None) -> str:
    """Newest *stable* (non-rc) kernel; mainline rc is intentionally skipped."""
    data = json.loads((fetch or (lambda: urllib.request.urlopen(RELEASES, timeout=20).read()))())
    return data["latest_stable"]["version"]


def build_script(version: str, workdir="/usr/src") -> list:
    """Shell steps: defconfig -> localmodconfig (only modules in use) -> build."""
    major = version.split(".")[0]
    return [
        f"curl -fLO https://cdn.kernel.org/pub/linux/kernel/v{major}.x/linux-{version}.tar.xz",
        f"tar -C {workdir} -xf linux-{version}.tar.xz",
        f"cd {workdir}/linux-{version}",
        "make x86_64_defconfig",
        # Needs the target's modules loaded (run from the live env after probing hardware)
        "yes '' | make localmodconfig",
        "scripts/config -e BTRFS_FS -e EFI_STUB -e DRM -e SQUASHFS",
        "make olddefconfig && make -j$(nproc) && make modules_install install",
    ]


def valid_version(v: str) -> bool:
    return bool(re.fullmatch(r"\d+\.\d+(\.\d+)?", v))
