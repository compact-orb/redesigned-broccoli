# Copyright 2023-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

CRATES="
	aho-corasick@1.1.4
	annotate-snippets@0.11.5
	anstyle@1.0.14
	anyhow@1.0.102
	async-channel@2.5.0
	autocfg@1.5.0
	bindgen@0.72.1
	bitflags@2.11.1
	cairo-rs@0.22.0
	cairo-sys-rs@0.22.0
	cc@1.2.61
	cexpr@0.6.0
	cfg-expr@0.20.7
	cfg-if@1.0.4
	cfg_aliases@0.2.1
	clang-sys@1.8.1
	concurrent-queue@2.5.0
	convert_case@0.8.0
	cookie-factory@0.3.3
	crossbeam-utils@0.8.21
	either@1.15.0
	equivalent@1.0.2
	event-listener@5.4.1
	event-listener-strategy@0.5.4
	field-offset@0.3.6
	find-msvc-tools@0.1.9
	futures-channel@0.3.32
	futures-core@0.3.32
	futures-executor@0.3.32
	futures-io@0.3.32
	futures-macro@0.3.32
	futures-task@0.3.32
	futures-util@0.3.32
	gdk-pixbuf-sys@0.22.0
	gdk-pixbuf@0.22.0
	gdk4-sys@0.11.2
	gdk4@0.11.2
	gio-sys@0.22.0
	gio@0.22.6
	glib-macros@0.22.6
	glib-sys@0.22.6
	glib@0.22.7
	glob@0.3.3
	gobject-sys@0.22.6
	graphene-rs@0.22.0
	graphene-sys@0.22.0
	gsk4-sys@0.11.1
	gsk4@0.11.1
	gtk4-macros@0.11.0
	gtk4-sys@0.11.3
	gtk4@0.11.3
	hashbrown@0.17.0
	heck@0.5.0
	indexmap@2.14.0
	itertools@0.13.0
	libadwaita-sys@0.9.1
	libadwaita@0.9.1
	libc@0.2.186
	libloading@0.8.9
	libspa-sys@0.9.2
	libspa@0.9.2
	log@0.4.29
	memchr@2.8.0
	memoffset@0.9.1
	minimal-lexical@0.2.1
	nix@0.30.1
	nom@7.1.3
	nom@8.0.0
	once_cell@1.21.4
	pango-sys@0.22.0
	pango@0.22.6
	parking@2.2.1
	pin-project-lite@0.2.17
	pipewire-sys@0.9.2
	pipewire@0.9.2
	pkg-config@0.3.33
	proc-macro-crate@3.5.0
	proc-macro2@1.0.106
	quote@1.0.45
	regex-automata@0.4.14
	regex-syntax@0.8.10
	regex@1.12.3
	rustc-hash@2.1.2
	rustc_version@0.4.1
	semver@1.0.28
	serde_core@1.0.228
	serde_derive@1.0.228
	serde_spanned@1.1.1
	shlex@1.3.0
	slab@0.4.12
	smallvec@1.15.1
	syn@2.0.117
	system-deps@7.0.8
	target-lexicon@0.13.3
	thiserror-impl@2.0.18
	thiserror@2.0.18
	toml@1.1.2+spec-1.1.0
	toml_datetime@1.1.1+spec-1.1.0
	toml_edit@0.25.11+spec-1.1.0
	toml_parser@1.1.2+spec-1.1.0
	toml_writer@1.1.1+spec-1.1.0
	unicode-ident@1.0.24
	unicode-segmentation@1.13.2
	unicode-width@0.2.2
	version-compare@0.2.1
	windows-link@0.2.1
	windows-sys@0.61.2
	winnow@1.0.2
"

LLVM_COMPAT=( {19..22} )

inherit cargo desktop llvm-r1 xdg

DESCRIPTION="A GTK patchbay for pipewire"
HOMEPAGE="https://gitlab.freedesktop.org/pipewire/helvum"
SRC_URI="
	https://gitlab.freedesktop.org/pipewire/helvum/-/archive/${PV}/${P}.tar.bz2
	${CARGO_CRATE_URIS}
"

LICENSE="GPL-3"
# Dependent crate licenses
LICENSE+="
	Apache-2.0 Apache-2.0-with-LLVM-exceptions BSD ISC MIT
	Unicode-DFS-2016
"
SLOT="0"
KEYWORDS="~amd64 ~arm64"

# Clang needed for bindgen
BDEPEND="
	>=dev-build/meson-1.8.0
	$(llvm_gen_dep '
		llvm-core/clang:${LLVM_SLOT}=
		llvm-core/llvm:${LLVM_SLOT}=
	')
	virtual/pkgconfig
"
DEPEND="
	>=dev-libs/glib-2.84.0:2
	>=gui-libs/gtk-4.18.0:4
	>=gui-libs/libadwaita-1.7:1
	media-libs/graphene
	>=media-video/pipewire-1.4.0:=
	x11-libs/cairo
	x11-libs/gdk-pixbuf:2
	x11-libs/pango
"
RDEPEND="${DEPEND}"

QA_FLAGS_IGNORED="usr/bin/${PN}"

pkg_setup() {
	llvm-r1_pkg_setup
	rust_pkg_setup
}

src_install() {
	cargo_src_install

	dodoc README.md

	doicon --size scalable data/icons/org.pipewire.Helvum.svg

	insopts -m 0644
	insinto /usr/share/icons/hicolor/symbolic/apps
	doins data/icons/org.pipewire.Helvum-symbolic.svg

	sed 's/@icon@/org.pipewire.Helvum/' \
		data/org.pipewire.Helvum.desktop.in > org.pipewire.Helvum.desktop || die
	domenu org.pipewire.Helvum.desktop

	sed 's/@app-id@/org.pipewire.Helvum/g' \
		data/org.pipewire.Helvum.metainfo.xml.in > org.pipewire.Helvum.metainfo.xml || die
	insinto /usr/share/metainfo
	doins org.pipewire.Helvum.metainfo.xml
}

pkg_postinst() {
	xdg_pkg_postinst
	xdg_icon_cache_update
}
