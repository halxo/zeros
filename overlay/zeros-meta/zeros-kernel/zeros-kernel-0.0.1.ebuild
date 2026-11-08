EAPI=8
DESCRIPTION="Builds the newest stable kernel tailored to this machine (zeros-kernel-build)"
HOMEPAGE="https://github.com/halxo/zeros"
LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64"
S="${WORKDIR}"
RDEPEND="sys-devel/bc sys-devel/flex sys-devel/bison dev-libs/openssl sys-libs/ncurses app-arch/xz-utils net-misc/curl"
src_install() { :; }
