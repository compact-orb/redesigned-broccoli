# Copyright 2011-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

CHROMIUM_LANGS="af am ar bg bn ca cs da de el en-GB es es-419 et fa fi fil fr gu he
	hi hr hu id it ja kn ko lt lv ml mr ms nb nl pl pt-BR pt-PT ro ru sk sl sr
	sv sw ta te th tr uk ur vi zh-CN zh-TW"

inherit chromium-2 desktop pax-utils unpacker xdg

DESCRIPTION="Chromium fork focused on high performance and security (binary version)"
HOMEPAGE="https://github.com/Alex313031/thorium"

if [[ ${PN} == thorium-bin ]]; then
	MY_PN=thorium-browser
else
	MY_PN=${PN}
fi

MY_PV="${PV}"
BASE_URI="https://github.com/Alex313031/thorium/releases/download/M${MY_PV}"

SRC_URI="
	cpu_flags_x86_avx2? ( ${BASE_URI}/${MY_PN}_${MY_PV}_AVX2.deb )
	!cpu_flags_x86_avx2? (
		cpu_flags_x86_avx? ( ${BASE_URI}/${MY_PN}_${MY_PV}_AVX.deb )
		!cpu_flags_x86_avx? (
			cpu_flags_x86_sse4_1? ( ${BASE_URI}/${MY_PN}_${MY_PV}_SSE4.deb )
			!cpu_flags_x86_sse4_1? ( ${BASE_URI}/${MY_PN}_${MY_PV}_SSE3.deb )
		)
	)
"
S=${WORKDIR}

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="-* amd64"

IUSE="cpu_flags_x86_sse3 cpu_flags_x86_sse4_1 cpu_flags_x86_avx cpu_flags_x86_avx2 qt6 selinux"

# Minimum requirement is SSE3 as per Thorium docs
REQUIRED_USE="|| ( cpu_flags_x86_sse3 cpu_flags_x86_sse4_1 cpu_flags_x86_avx cpu_flags_x86_avx2 )"

RESTRICT="bindist mirror strip"

RDEPEND="
	>=app-accessibility/at-spi2-core-2.46.0:2
	app-misc/ca-certificates
	dev-libs/expat
	dev-libs/glib:2
	dev-libs/nspr
	>=dev-libs/nss-3.26
	media-fonts/liberation-fonts
	media-libs/alsa-lib
	media-libs/mesa[gbm(+)]
	net-misc/curl
	net-print/cups
	sys-apps/dbus
	sys-libs/glibc
	sys-libs/libcap
	x11-libs/cairo
	x11-libs/gdk-pixbuf:2
	|| (
		x11-libs/gtk+:3[X]
		gui-libs/gtk:4[X]
	)
	x11-libs/libdrm
	>=x11-libs/libX11-1.5.0
	x11-libs/libXcomposite
	x11-libs/libXdamage
	x11-libs/libXext
	x11-libs/libXfixes
	x11-libs/libXrandr
	x11-libs/libxcb
	x11-libs/libxkbcommon
	x11-libs/libxshmfence
	x11-libs/pango
	x11-misc/xdg-utils
	qt6? ( dev-qt/qtbase:6[gui,widgets] )
	selinux? ( sec-policy/selinux-chromium )
"

QA_PREBUILT="*"
QA_DESKTOP_FILE="usr/share/applications/${MY_PN}.desktop"
CHROME_HOME="opt/chromium.org/thorium"

pkg_nofetch() {
	eerror "Please wait 24 hours and sync your tree before reporting a bug for thorium-bin fetch failures."
}

pkg_pretend() {
	# Protect against people using autounmask overzealously
	use amd64 || die "thorium-bin only works on amd64"
}

pkg_setup() {
	chromium_suid_sandbox_check_kernel_config
}

src_unpack() {
	:
}

upstream_src_install() {
	dodir /
	cd "${ED}" || die
	unpacker

	# Cleanup cron/scripts not needed on Gentoo
	rm -r etc/cron.daily || die "Failed to remove cron scripts"
	rm -r "${CHROME_HOME}"/cron || die "Failed to remove cron scripts"

	pushd "${CHROME_HOME}/locales" > /dev/null || die
	chromium_remove_language_paks
	popd > /dev/null || die

	rm "${CHROME_HOME}/libqt5_shim.so" || die
	if ! use qt6; then
		rm "${CHROME_HOME}/libqt6_shim.so" || die
	fi

	local size
	for size in 16 24 32 48 64 128 256 ; do
		if [[ -f "${CHROME_HOME}/product_logo_${size}.png" ]]; then
			newicon -s ${size} "${CHROME_HOME}/product_logo_${size}.png" ${MY_PN}.png
		fi
	done

	fperms 4755 "/${CHROME_HOME}/chrome-sandbox"

	pax-mark m "/${CHROME_HOME}/thorium-browser"
}

src_install() {
    upstream_src_install

    # Binary symlinks
    dodir /usr/bin
    dosym "/${CHROME_HOME}/thorium-browser" /usr/bin/thorium-browser
    if [[ -f "${ED}/${CHROME_HOME}/thorium-shell" ]]; then
        dosym "/${CHROME_HOME}/thorium-shell" /usr/bin/thorium-shell
    fi
}
