# Copyright 1999-2022 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

DB_VER="4.8"
inherit autotools bash-completion-r1 db-use systemd

BITCOINCORE_COMMITHASH="af591f2068d0363c92d9756ca39c43db85e5804c"
KNOTS_PV="${PV}.knots20210629"
KNOTS_P="bitcoin-${KNOTS_PV}"

DESCRIPTION="Original Bitcoin crypto-currency wallet for automated services"
HOMEPAGE="https://bitcoincore.org/ https://bitcoinknots.org/"
SRC_URI="
	https://github.com/bitcoin/bitcoin/archive/${BITCOINCORE_COMMITHASH}.tar.gz -> bitcoin-v0.${PV}.tar.gz
	https://bitcoinknots.org/files/21.x/${KNOTS_PV}/${KNOTS_P}.patches.txz -> ${KNOTS_P}.patches.tar.xz
"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64 ~arm ~arm64 ~mips ~ppc ~ppc64 ~x86 ~amd64-linux ~x86-linux"
IUSE="+asm +berkdb examples knots sqlite test upnp +wallet zeromq"
RESTRICT="!test? ( test )"

REQUIRED_USE="
	sqlite? ( wallet )
	berkdb? ( wallet )
	wallet? ( || ( berkdb sqlite ) )
"
DEPEND="
	acct-group/bitcoin
	acct-user/bitcoin
	dev-libs/boost:=
	dev-libs/libevent:=
	>dev-libs/libsecp256k1-0.1_pre20200911:=[recovery,schnorr]
	>=dev-libs/univalue-1.0.4:=
	virtual/bitcoin-leveldb
	sqlite? ( >=dev-db/sqlite-3.7.17:= )
	upnp? ( >=net-libs/miniupnpc-1.9.20150916:= )
	berkdb? ( sys-libs/db:$(db_ver_to_slot "${DB_VER}")=[cxx] )
	zeromq? ( net-libs/zeromq:= )
"
RDEPEND="${DEPEND}"
BDEPEND="
	>=sys-devel/automake-1.13
"

DOCS=(
	doc/bips.md
	doc/bitcoin-conf.md
	doc/descriptors.md
	doc/files.md
	doc/JSON-RPC-interface.md
	doc/psbt.md
	doc/reduce-memory.md
	doc/reduce-traffic.md
	doc/release-notes.md
	doc/REST-interface.md
	doc/tor.md
)

S="${WORKDIR}/bitcoin-${BITCOINCORE_COMMITHASH}"

pkg_pretend() {
	if use knots; then
		elog "You are building ${PN} from Bitcoin Knots."
		elog "For more information, see:"
		elog "https://bitcoinknots.org/files/21.x/${KNOTS_PV}/${KNOTS_P}.desc.html"
	else
		elog "You are building ${PN} from Bitcoin Core."
		elog "For more information, see:"
		elog "https://bitcoincore.org/en/2021/09/29/release-0.${PV}/"
	fi
	elog
	elog "Replace By Fee policy is now always enabled by default: Your node will"
	elog "preferentially mine and relay transactions paying the highest fee, regardless"
	if use knots; then
		elog "of receive order. To disable RBF, set mempoolreplacement=never in bitcoin.conf"
	else  # Bitcoin Core doesn't support disabling RBF anymore
		elog "of receive order. To disable RBF, rebuild with USE=knots to get ${PN}"
		elog "from Bitcoin Knots, and set mempoolreplacement=never in bitcoin.conf"
	fi
	if has_version "<${CATEGORY}/${PN}-0.21.1" ; then
		ewarn "CAUTION: BITCOIN PROTOCOL CHANGE INCLUDED"
		ewarn "This release adds enforcement of the Taproot protocol change to the Bitcoin"
		ewarn "rules, beginning in November. Protocol changes require user consent to be"
		ewarn "effective, and if enforced inconsistently within the community may compromise"
		ewarn "your security or others! If you do not know what you are doing, learn more"
		ewarn "before November. (You must make a decision either way - simply not upgrading"
		ewarn "is insecure in all scenarios.)"
		ewarn "To learn more, see https://bitcointaproot.cc"
	fi
}

src_prepare() {
	sed -i 's/^\(complete -F _bitcoind bitcoind\) bitcoin-qt$/\1/' contrib/${PN}.bash-completion || die

	local knots_patchdir="${WORKDIR}/${KNOTS_P}.patches/"

	eapply "${knots_patchdir}/${KNOTS_P}_p1-syslibs.patch"

	if use knots; then
		eapply "${knots_patchdir}/${KNOTS_P}_p2-fixes.patch"
		eapply "${knots_patchdir}/${KNOTS_P}_p3-features.patch"
		eapply "${knots_patchdir}/${KNOTS_P}_p4-branding.patch"
		eapply "${knots_patchdir}/${KNOTS_P}_p5-ts.patch"
	fi

	default

	eautoreconf
	rm -r src/leveldb src/secp256k1 || die
}

src_configure() {
	local my_econf=(
		$(use_enable asm)
		--without-qtdbus
		--without-qrencode
		$(use_with upnp miniupnpc)
		$(use_enable upnp upnp-default)
		$(use_enable test tests)
		$(use_enable wallet)
		$(use_enable zeromq zmq)
		--with-daemon
		--disable-util-cli
		--disable-util-tx
		--disable-util-wallet
		--disable-bench
		--without-libs
		--without-gui
		--disable-fuzz
		--disable-ccache
		--disable-static
		$(use_with berkdb bdb)
		$(use_with sqlite)
		--with-system-leveldb
		--with-system-libsecp256k1
		--with-system-univalue
	)
	econf "${my_econf[@]}"
}

src_install() {
	default

	if use test; then
		rm -f "${ED}/usr/bin/test_bitcoin" || die
	fi

	insinto /etc/bitcoin
	newins "${FILESDIR}/bitcoin.conf" bitcoin.conf
	fowners bitcoin:bitcoin /etc/bitcoin/bitcoin.conf
	fperms 600 /etc/bitcoin/bitcoin.conf

	newconfd "contrib/init/bitcoind.openrcconf" ${PN}
	newinitd "contrib/init/bitcoind.openrc" ${PN}
	systemd_newunit "contrib/init/bitcoind.service" "bitcoind.service"

	keepdir /var/lib/bitcoin/.bitcoin
	fperms 700 /var/lib/bitcoin
	fowners bitcoin:bitcoin /var/lib/bitcoin/
	fowners bitcoin:bitcoin /var/lib/bitcoin/.bitcoin
	dosym ../../../../etc/bitcoin/bitcoin.conf /var/lib/bitcoin/.bitcoin/bitcoin.conf

	doman "${FILESDIR}/bitcoin.conf.5"

	use zeromq && dodoc doc/zmq.md

	newbashcomp contrib/${PN}.bash-completion ${PN}

	if use examples; then
		docinto examples
		dodoc -r contrib/{linearize,qos}
		use zeromq && dodoc -r contrib/zmq
	fi

	insinto /etc/logrotate.d
	newins "${FILESDIR}/bitcoind.logrotate-r1" bitcoind
}

pkg_postinst() {
	elog "To have ${PN} automatically use Tor when it's running, be sure your"
	elog "'torrc' config file has 'ControlPort' and 'CookieAuthentication' setup"
	elog "correctly, and:"
	elog "- Using an init script: add the 'bitcoin' user to the 'tor' user group."
	elog "- Running bitcoind directly: add that user to the 'tor' user group."
}
