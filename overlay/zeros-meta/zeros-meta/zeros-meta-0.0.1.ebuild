EAPI=8
DESCRIPTION="Zeros base system: OpenRC, elogind, Btrfs, Hyprland+macshell, zeros tooling"
HOMEPAGE="https://github.com/halxo/zeros"
LICENSE="metapackage"
SLOT="0"
KEYWORDS="~amd64"
RDEPEND="
	sys-apps/openrc sys-auth/elogind sys-apps/dbus sys-fs/btrfs-progs
	net-misc/networkmanager app-admin/sudo
	zeros-meta/zeros-tools zeros-meta/zeros-kernel zeros-meta/zeros-macshell
"
