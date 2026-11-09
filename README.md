# Zeros OS
Rolling-release, **source-based** Linux OS: "Gentoo, but automatic." Built on Gentoo/Portage with an automation layer that detects your hardware, generates `make.conf` + a tailored kernel config, and compiles the newest stable Linux kernel for your machine. OpenRC + Hyprland (macshell UI).

- **Rolling**: every green push to `main` produces a tested rolling release with downloadable bootable ISO.
- **Milestones**: named milestone releases (e.g. **Zeros Nova**) with official verified ISOs.
- **UEFI Secure Boot**: signed with Microsoft UEFI CA shim — boots straight away on retail Windows PCs and laptops without needing BIOS changes.
- **Graphical Live Desktop**: boots directly into a live Hyprland desktop with the frosted `macshell` top panel and an auto-centering installation wizard.
- **Safe updates**: Btrfs atomic snapshots before each update; automatic rollback on boot failure.
- **Fast installs**: optional hardware-profile binary cache; otherwise compiles natively.

---

## 🚀 Downloading & Booting Zeros

### 1. Download Latest ISO
Download the newest release from [Zeros GitHub Releases](https://github.com/halxo/zeros/releases).

### 2. Flashing to USB
* **Linux / macOS:**
  ```bash
  sudo dd if=zeros-*.iso of=/dev/sdX bs=4M status=progress oflag=sync
  ```
  *(Replace `/dev/sdX` with your USB drive name, e.g. `/dev/sdb` or `/dev/disk2`)*
* **Windows:**
  * Use **Balena Etcher** or **Raspberry Pi Imager** to write the ISO.
  * If using **Rufus**, select **"Write in DD Image mode"** when prompted.

### 3. PC Booting & Firmware Compatibility
* **UEFI Secure Boot Supported:** Ships with Microsoft-signed `shim` (`BOOTX64.EFI`) and signed GRUB. Retail laptops (Surface, Dell, HP, Lenovo, ASUS, etc.) can boot directly with Secure Boot enabled.
* **Legacy BIOS Supported:** Built with hybrid MBR El Torito bootloader for older PCs.
* **Boot Menu:** Power on the PC and press your boot menu key (`F12` on Dell/Lenovo, `F9` on HP, `F8` on ASUS, `F11` on MSI) to select your USB drive.

---

## 🖥️ Live Desktop & Installation

### Live Session Options
When the ISO boots:
1. **Default Live Desktop:** Automatically boots into a graphical Hyprland session with:
   - Frosted translucent top bar (`macshell` Waybar) displaying hardware status (CPU, RAM, GPU, Battery, Network, Clock).
   - "⚡ Install Zeros" quick-action launcher in the menu bar.
   - An auto-centering floating installer wizard window.
   - Spotlight search launcher via `Super + Space`.
   - Terminal emulator via `Super + Enter`.
2. **Safe Graphics Mode (`nomodeset`):** Selectable from GRUB menu for problematic discrete GPUs.
3. **Console TUI Mode:** Automatically falls back to the interactive TUI wizard on serial or text-only consoles.

### Running the Installer
* **Interactive Graphical / TUI Wizard:**
  ```bash
  zeros-installer
  ```
* **Command Line (Dry-Run / Preview):**
  ```bash
  zeros-install /dev/nvme0n1
  ```
* **Command Line (Real Execution):**
  ```bash
  zeros-install /dev/nvme0n1 --really
  ```

---

## 💻 Local Development & Testing
```bash
python3 -m venv venv && source venv/bin/activate
pip install pytest
pytest tests
python3 -m zeros.detect --make-conf
```
