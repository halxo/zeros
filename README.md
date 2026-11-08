# Zeros
Rolling-release, **source-based** Linux OS: "Gentoo, but automatic." Built on Gentoo/Portage with an automation layer that detects your hardware, generates `make.conf` + a tailored kernel config, and compiles the newest stable Linux kernel for your machine. OpenRC + Hyprland (macshell UI).

- **Rolling**: every green push to `main` gets a `rolling-YYYY.MM.DD-HHMM` pre-release.
- **Milestones**: occasionally a named release (e.g. *Zeros Nova*) is minted via the Release workflow (`milestone=true`).
- **Safe updates**: Btrfs snapshot before each update; if a boot is never confirmed (`zeros-bootok`), roll back.
- **Fast installs**: optional binary cache keyed by hardware profile hash; otherwise compile locally.

> Status: early scaffold. The installer is dry-run by default. See [docs/ROADMAP.md](docs/ROADMAP.md).

## Try it
```
pip install pytest && pytest tests
PYTHONPATH=zeros_py python3 -m zeros.detect --make-conf
sudo installer/zeros-install.sh /dev/sdX        # dry run: prints steps only
```
