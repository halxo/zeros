# Zeros OS
Rolling-release, **source-based** Linux OS: "Gentoo, but automatic." Built on Gentoo/Portage with an automation layer that detects your hardware, generates `make.conf` + a tailored kernel config, and compiles the newest stable Linux kernel for your machine. OpenRC + Hyprland (macshell UI).

- **Rolling**: every green push to `main` produces a tested rolling pre-release.
- **Milestones**: named stable releases (e.g. **Zeros Nova**) with official verified ISOs.
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

### 3. PC Firmware Settings (Crucial for Everyday Computers)
* **Disable Secure Boot:** In your computer's BIOS/UEFI settings (typically `F2`, `F10`, `F12`, or `Del` at startup), go to **Security** or **Boot** and set **Secure Boot: Disabled**. Custom kernels and source-based distributions require Secure Boot to be disabled.
* **Boot Menu:** Power on the PC and press `F12` (Dell/Lenovo), `F9` (HP), `F8` (ASUS), or `F11` (MSI) to select your USB drive.

---

## 🛠️ Installing Zeros OS

Once booted into the Zeros live console:
* **Interactive Wizard:**
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
