# Copyright 1999-2016 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=5
inherit eutils toolchain-funcs

DESCRIPTION="DHCP Packet Analyzer/tcpdump postprocessor"
HOMEPAGE="http://www.mavetju.org/unix/general.php"
SRC_URI="http://www.mavetju.org/download/${P}.tar.gz"

LICENSE="BSD-2"
SLOT="0"
KEYWORDS="amd64 ~mips x86 arm"

RDEPEND="net-libs/libpcap"
DEPEND="
	${RDEPEND}
	dev-lang/perl
"

src_prepare() {
	epatch "${FILESDIR}"/${P}-Makefile.patch
	epatch "${FILESDIR}"/${P}-debian.patch
	epatch "${FILESDIR}"/${P}-endianness.patch
}

src_compile() {
	emake CC=$(tc-getCC)
}

src_install () {
	dobin ${PN}
	doman ${PN}.8
	dodoc CHANGES CONTACT
}
