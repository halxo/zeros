# Architecture
| Layer | Choice |
|---|---|
| Base | Gentoo/Portage (stage3 + Zeros overlay `zeros-meta`) |
| Kernel | newest *stable* from kernel.org, `localmodconfig`-trimmed per machine (`zeros.kernel`) |
| Init | OpenRC (+ elogind, no systemd) |
| Desktop | Hyprland + macshell |
| Boot | UEFI: EFI-stub/limine/GRUB; BIOS: GRUB. (No systemd-boot dependency.) |
| FS | Btrfs, `@` + `@snapshots` |
| Updates | `zeros-update`: snapshot -> `emerge -uDN @world` -> pending -> `zeros-bootok` confirms -> else rollback |
| Cache | Prebuilt binpkgs per hardware `cache_key` published as GitHub release assets; signed |

Rolling updates land continuously on `main`; CI gates them. Named milestones are manual.
