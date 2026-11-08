"""Fetch newest stable kernel version and build a hardware-tailored config."""
import json, re, subprocess, urllib.request

RELEASES = "https://www.kernel.org/releases.json"


def latest_stable(fetch=None) -> str:
    """Newest *stable* (non-rc) kernel; mainline rc is intentionally skipped."""
    data = json.loads((fetch or (lambda: urllib.request.urlopen(RELEASES, timeout=20).read()))())
    return data["latest_stable"]["version"]


def build_script(version: str, workdir="/usr/src") -> list:
    """Shell steps: defconfig -> localmodconfig -> ensure essential hardware drivers -> build."""
    major = version.split(".")[0]
    return [
        f"curl -fLO https://cdn.kernel.org/pub/linux/kernel/v{major}.x/linux-{version}.tar.xz",
        f"tar -C {workdir} -xf linux-{version}.tar.xz",
        f"cd {workdir}/linux-{version}",
        "make x86_64_defconfig",
        # Auto-trim to current machine hardware
        "yes '' | make localmodconfig",
        # Explicitly enable drivers required to boot natively on ANY modern PC hardware:
        # NVMe, SATA AHCI, USB storage, Btrfs, EFI Stub, VFAT/ESP, Display SimpleDRM/SysFB, Keyboard/Mouse HID
        "scripts/config -e BTRFS_FS -e BLK_DEV_NVME -e NVME_CORE -e SATA_AHCI -e USB_STORAGE "
        "-e EFI_STUB -e EFI_PARTITION -e EFIVAR_FS -e VFAT_FS -e FAT_FS -e NLS_CODEPAGE_437 -e NLS_ISO8859_1 "
        "-e DRM -e DRM_SIMPLEDRM -e SYSFB_SIMPLEFB -e FB_EFI -e INPUT_EVDEV -e KEYBOARD_ATKBD -e HID_GENERIC -e USB_HID "
        "-e DEVTMPFS -e DEVTMPFS_MOUNT -e SQUASHFS -e KVM_GUEST",
        "make olddefconfig && make -j$(nproc) && make modules_install install",
    ]


def valid_version(v: str) -> bool:
    return bool(re.fullmatch(r"\d+\.\d+(\.\d+)?", v))
