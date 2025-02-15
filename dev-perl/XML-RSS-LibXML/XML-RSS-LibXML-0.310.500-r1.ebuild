# Copyright 1999-2022 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DIST_AUTHOR=DMAKI
DIST_VERSION=0.3105
inherit perl-module

DESCRIPTION="XML::RSS with XML::LibXML"
SLOT="0"
KEYWORDS="amd64 ~arm64 ~ppc64 ~x86"
IUSE="minimal"

RDEPEND="
	dev-perl/Class-Accessor
	dev-perl/DateTime-Format-Mail
	dev-perl/DateTime-Format-W3CDTF
	virtual/perl-Encode
	dev-perl/UNIVERSAL-require
	>=dev-perl/XML-LibXML-1.660.0
"
BDEPEND="${RDEPEND}
	>=dev-perl/Module-Build-0.380.0
	virtual/perl-CPAN-Meta
	test? (
		!minimal? (
			dev-perl/Test-Exception
			dev-perl/Test-Warn
		)
	)
"
