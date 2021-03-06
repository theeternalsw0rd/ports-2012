# Distributed under the terms of the GNU General Public License v2

EAPI="5"
GCONF_DEBUG="no"
PYTHON_COMPAT=( python2_7 )

inherit check-reqs cmake-utils eutils flag-o-matic gnome2 pax-utils python-any-r1 toolchain-funcs versionator virtualx

MY_P="webkitgtk-${PV}"
DESCRIPTION="Open source web browser engine"
HOMEPAGE="http://www.webkitgtk.org/"
SRC_URI="http://www.webkitgtk.org/releases/${MY_P}.tar.xz"

LICENSE="LGPL-2+ BSD"
SLOT="4/37" # soname version of libwebkit2gtk-4.0
KEYWORDS="*"
IUSE="coverage debug +egl +geoloc gles2 +gstreamer +introspection +jit libsecret +opengl spell wayland +webgl +X"
# bugs 372493, 416331
REQUIRED_USE="
	geoloc? ( introspection )
	introspection? ( gstreamer )
	gles2? ( egl )
	webgl? ( ^^ ( gles2 opengl ) )
	!webgl? ( ?? ( gles2 opengl ) )
	|| ( wayland X )
"

# use sqlite, svg by default
# Aqua support in gtk3 is untested
# gtk2 is needed for plugin process support
# gtk3-3.10 required for wayland
RDEPEND="
	>=dev-libs/glib-2.36.0:2
	>=dev-libs/libxml2-2.8:2
	>=dev-libs/libxslt-1.1.7
	virtual/jpeg:0=
	>=media-libs/harfbuzz-0.9.18:=[icu(+)]
	>=media-libs/libpng-1.4:0=
	media-libs/libwebp:=
	>=dev-libs/icu-3.8.1-r1:=
	>=media-libs/fontconfig-2.8:1.0
	>=media-libs/freetype-2.4.2:2
	>=net-libs/libsoup-2.42.0:2.4[introspection?]
	>=x11-libs/cairo-1.10.2:=[X]
	>=x11-libs/gtk+-3.6.0:3[X?,introspection?]
	dev-db/sqlite:3=
	>=x11-libs/pango-1.30.0.0
	x11-libs/libXrender
	x11-libs/libXt
	>=x11-libs/gtk+-2.24.10:2

	egl? ( media-libs/mesa[egl] )
	geoloc? ( >=app-misc/geoclue-2.1.5:2.0 )
	gles2? ( media-libs/mesa[gles2] )
	gstreamer? (
		>=media-libs/gstreamer-1.2:1.0
		>=media-libs/gst-plugins-base-1.2:1.0 )
	introspection? ( >=dev-libs/gobject-introspection-1.32.0 )
	libsecret? ( app-crypt/libsecret )
	opengl? ( virtual/opengl )
	spell? ( >=app-text/enchant-0.22:= )
	wayland? ( >=x11-libs/gtk+-3.12:3[wayland] )
	webgl? (
		x11-libs/cairo[opengl]
		x11-libs/libXcomposite
		x11-libs/libXdamage )
"

# paxctl needed for bug #407085
# Need real bison, not yacc
DEPEND="${RDEPEND}
	${PYTHON_DEPS}
	>=dev-lang/perl-5.10
	|| (
		virtual/rubygems[ruby_targets_ruby20]
		virtual/rubygems[ruby_targets_ruby21]
		virtual/rubygems[ruby_targets_ruby19]
	)
	>=app-accessibility/at-spi2-core-2.5.3
	>=dev-libs/atk-2.8.0
	>=dev-util/gtk-doc-am-1.10
	>=dev-util/gperf-3.0.1
	>=sys-devel/bison-2.4.3
	>=sys-devel/flex-2.5.34
	|| ( >=sys-devel/gcc-4.7 >=sys-devel/clang-3.3 )
	sys-devel/gettext
	>=sys-devel/make-3.82-r4
	virtual/pkgconfig

	geoloc? ( dev-util/gdbus-codegen )
	introspection? ( jit? ( sys-apps/paxctl ) )
	test? (
		dev-lang/python:2.7
		dev-python/pygobject:3[python_targets_python2_7]
		x11-themes/hicolor-icon-theme
		jit? ( sys-apps/paxctl ) )
"

S="${WORKDIR}/${MY_P}"

CHECKREQS_DISK_BUILD="18G" # and even this might not be enough, bug #417307

pkg_pretend() {
	nvidia_check || die #463960

	if [[ ${MERGE_TYPE} != "binary" ]] && is-flagq "-g*" && ! is-flagq "-g*0" ; then
		einfo "Checking for sufficient disk space to build ${PN} with debugging CFLAGS"
		check-reqs_pkg_pretend
	fi

	if ! test-flag-CXX -std=c++11; then
		die "You need at least GCC 4.7.x or Clang >= 3.3 for C++11-specific compiler flags"
	fi
}

pkg_setup() {
	nvidia_check || die #463960

	# Check whether any of the debugging flags is enabled
	if [[ ${MERGE_TYPE} != "binary" ]] && is-flagq "-g*" && ! is-flagq "-g*0" ; then
		if is-flagq "-ggdb" && [[ ${WEBKIT_GTK_GGDB} != "yes" ]]; then
			replace-flags -ggdb -g
			ewarn "Replacing \"-ggdb\" with \"-g\" in your CFLAGS."
			ewarn "Building ${PN} with \"-ggdb\" produces binaries which are too"
			ewarn "large for current binutils releases (bug #432784) and has very"
			ewarn "high temporary build space and memory requirements."
			ewarn "If you really want to build ${PN} with \"-ggdb\", add"
			ewarn "WEBKIT_GTK_GGDB=yes"
			ewarn "to your make.conf file."
		fi
		einfo "You need to have at least 18GB of temporary build space available"
		einfo "to build ${PN} with debugging CFLAGS. Note that it might still"
		einfo "not be enough, as the total space requirements depend on the flags"
		einfo "(-ggdb vs -g1) and enabled features."
		check-reqs_pkg_setup
	fi

	[[ ${MERGE_TYPE} = "binary" ]] || python-any-r1_pkg_setup
}

src_prepare() {
	# Debian patches to fix support for some arches
	# https://bugs.webkit.org/show_bug.cgi?id=129540
	epatch "${FILESDIR}"/${PN}-2.6.0-{hppa,ia64}-platform.patch

	# https://bugs.webkit.org/show_bug.cgi?id=129542
	epatch "${FILESDIR}"/${PN}-2.6.0-ia64-malloc.patch

	# Fix building on ppc (from OpenBSD, only needed on slot 3)
	# https://bugs.webkit.org/show_bug.cgi?id=130837
	epatch "${FILESDIR}"/${PN}-2.6.0-atomic-ppc.patch

	gnome2_src_prepare
}

src_configure() {
	# Respect CC, otherwise fails on prefix #395875
	tc-export CC

	# Arches without JIT support also need this to really disable it in all places
	use jit || append-cppflags -DENABLE_JIT=0 -DENABLE_YARR_JIT=0 -DENABLE_ASSEMBLER=0

	# It doesn't compile on alpha without this in LDFLAGS, bug #???
	use alpha && append-ldflags "-Wl,--no-relax"

	# Sigbuses on SPARC with mcpu and co., bug #???
	use sparc && filter-flags "-mvis"

	# https://bugs.webkit.org/show_bug.cgi?id=42070 , #301634
	use ppc64 && append-flags "-mminimal-toc"

	# Try to use less memory, bug #469942 (see Fedora .spec for reference)
	# --no-keep-memory doesn't work on ia64, bug #502492
	if ! use ia64; then
		append-ldflags "-Wl,--no-keep-memory"
	fi
	if ! $(tc-getLD) --version | grep -q "GNU gold"; then
		append-ldflags "-Wl,--reduce-memory-overheads"
	fi

	local ruby_interpreter=""

	if has_version "virtual/rubygems[ruby_targets_ruby21]"; then
		ruby_interpreter="RUBY=$(type -P ruby21)"
	elif has_version "virtual/rubygems[ruby_targets_ruby20]"; then
		ruby_interpreter="RUBY=$(type -P ruby20)"
	else
		ruby_interpreter="RUBY=$(type -P ruby19)"
	fi

	# TODO: Check Web Audio support
	# should somehow let user select between them?
	#
	# FTL_JIT requires llvm + libcxxabi
	local mycmakeargs=(
		$(cmake-utils_use_enable test API_TESTS)
		$(cmake-utils_use_enable geoloc GEOLOCATION)
		$(cmake-utils_use_enable gstreamer VIDEO)
		$(cmake-utils_use_enable gstreamer WEB_AUDIO)
		$(cmake-utils_use_enable jit)
		$(cmake-utils_use_enable libsecret CREDENTIAL_STORAGE)
		$(cmake-utils_use_enable spell SPELLCHECK SPELLCHECK)
		$(cmake-utils_use_enable wayland WAYLANG_TARGET)
		$(cmake-utils_use_enable webgl WEBGL)
		$(cmake-utils_use_enable X X11_TARGET)
		$(cmake-utils_use_find_package egl EGL)
		$(cmake-utils_use_find_package introspection GobjectIntrospection)
		$(cmake-utils_use_find_package opengl OpenGL)
		-DPORT=GTK
		-DENABLE_GTKDOC=OFF
		-DENABLE_PLUGIN_PROCESS_GTK2=ON
		${ruby_interpreter}
	)

	cmake-utils_src_configure
}

src_compile() {
	cmake-utils_src_compile
}

src_test() {
	# Prevents test failures on PaX systems
	use jit && pax-mark m $(list-paxables Programs/*[Tt]ests/*) # Programs/unittests/.libs/test*

	cmake-utils_src_test
}

src_install() {
	cmake-utils_src_install

	# Prevents crashes on PaX systems, bug #522808
	use jit && pax-mark m "${ED}usr/bin/jsc-3" "${ED}usr/libexec/WebKitWebProcess"
	pax-mark m "${ED}usr/libexec/WebKitPluginProcess"
}

nvidia_check() {
	if [[ ${MERGE_TYPE} != "binary" ]] &&
	   use introspection &&
	   has_version '=x11-drivers/nvidia-drivers-325*' &&
	   [[ $(eselect opengl show 2> /dev/null) = "nvidia" ]]
	then
		eerror "${PN} freezes while compiling if x11-drivers/nvidia-drivers-325.* is"
		eerror "used as the system OpenGL library."
		eerror "You can either update to >=nvidia-drivers-331.13, or temporarily select"
		eerror "Mesa as the system OpenGL library:"
		eerror " # eselect opengl set xorg-x11"
		eerror "See https://bugs.gentoo.org/463960 for more details."
		eerror
		return 1
	fi
}
