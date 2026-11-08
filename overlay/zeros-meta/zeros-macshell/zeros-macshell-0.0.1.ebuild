EAPI=8
DESCRIPTION="Mac-style Hyprland shell for Zeros (top bar, dock, blur, theme)"
HOMEPAGE="https://github.com/halxo/zeros"
EGIT_REPO_URI="https://github.com/halxo/zeros.git"
inherit git-r3
LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64"
RDEPEND="gui-wm/hyprland gui-apps/waybar x11-misc/nwg-dock-hyprland gui-apps/wofi gui-apps/swaybg x11-terms/kitty"
src_unpack() { git-r3_src_unpack; }
src_install() {
	insinto /etc/skel/.config/hypr;  doins macshell/hypr/hyprland.conf
	insinto /etc/skel/.config/waybar; doins macshell/waybar/config macshell/waybar/style.css
}
