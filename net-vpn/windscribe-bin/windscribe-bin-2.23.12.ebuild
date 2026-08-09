# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit unpacker xdg

DESCRIPTION="Windscribe VPN desktop client"
HOMEPAGE="https://windscribe.com"
SRC_URI="
	amd64? ( https://github.com/Windscribe/Desktop-App/releases/download/v${PV}/windscribe_${PV}_amd64.deb )
	arm64? ( https://github.com/Windscribe/Desktop-App/releases/download/v${PV}/windscribe_${PV}_arm64.deb )
"
S="${WORKDIR}"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="-* ~amd64 ~arm64"
RESTRICT="bindist mirror"

RDEPEND="
	sys-apps/dbus
	sys-libs/glibc
"

QA_PREBUILT="
	opt/windscribe/*
"

src_unpack() {
	:
}

src_install() {
	dodir /
	cd "${ED}" || die
	unpacker

	# Symlink CLI to PATH
	dosym /opt/windscribe/windscribe-cli /usr/bin/windscribe-cli

	# Remove the deb's preset file, not needed on Gentoo
	rm -r "${ED}"/usr/lib/systemd/system-preset || die

	# Remove autostart entry (let user manage it)
	rm -r "${ED}"/etc || die
}
