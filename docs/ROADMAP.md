# Roadmap (agent-workable tasks)
Each item is a self-contained task suited to an autonomous agent with tests as the acceptance gate.
1. **Detect** (done): profile, make.conf, cache key. TODO: firmware/Wi-Fi/NVIDIA driver selection, ARM later.
2. **Kernel**: run `build_script` in a QEMU CI job; boot-test result.
3. **Overlay**: create `zeros-overlay` repo with `zeros-meta`, `zeros-updater`, OpenRC services as ebuilds.
4. **macshell**: Hyprland config/theme, dock, top bar (Quickshell/AGS).
5. **Binary cache pipeline**: matrix-build common profiles (generic, znver*, intel gens) in Actions -> release assets, signed.
6. **Installer**: real ISO (catalyst/livegui), TUI + GUI front end, `--really` gated tests in QEMU.
7. **Update gating**: nightly full-world build + QEMU boot test before a rolling tag is published.
8. **Bootloader rollback hook**: boot-counting (BLS entries / GRUB `boot_indeterminate`) to auto-revert.
9. **Milestones**: dispatch Release with `milestone=true`.
