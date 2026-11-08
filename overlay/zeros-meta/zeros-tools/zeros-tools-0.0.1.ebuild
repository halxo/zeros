# Copyright 2026 Zeros contributors
# Distributed under the terms of the MIT License
EAPI=8
PYTHON_COMPAT=( python3_{11..13} )
inherit python-single-r1
DESCRIPTION="Zeros hardware detection, kernel builder and rolling updater"
HOMEPAGE="https://github.com/halxo/zeros"
EGIT_REPO_URI="https://github.com/halxo/zeros.git"
inherit git-r3
LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64"
REQUIRED_USE="${PYTHON_REQUIRED_USE}"
RDEPEND="${PYTHON_DEPS} sys-fs/btrfs-progs sys-apps/pciutils"
S="${WORKDIR}/${P}"
src_unpack() { git-r3_src_unpack; }
src_install() {
	python_domodule zeros_py/zeros
	for t in detect:zeros-detect updater:zeros-update; do
		printf '#!/bin/sh\nexec %s -m zeros.%s "$@"\n' "${PYTHON}" "${t%%:*}" > "${T}/${t##*:}"
		dobin "${T}/${t##*:}"
	done
	newinitd openrc/zeros-bootok zeros-bootok
	dobin installer/zeros-install.sh
}
