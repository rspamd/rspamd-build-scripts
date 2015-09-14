#!/bin/sh

DISTRIBS="ubuntu-precise
		ubuntu-trusty
		ubuntu-vivid
		debian-jessie
		debian-wheezy"
RSPAMD_VER="1.0.0"
RMILTER_VER="1.6.4"


DEPS="debhelper dpkg-dev cmake libevent-dev libglib2.0-dev libgmime-2.6-dev libpcre3-dev libssl-dev libcurl4-openssl-dev libhiredis-dev libsqlite3-dev perl libopendkim-dev libmilter-dev libspf2-dev bison flex"
export DEBIAN_FRONTEND="noninteractive"
export LANG="C"
export DEB_BUILD_OPTIONS="parallel=8 nostrip"

_version=`cat ${HOME}/version || echo 0`
if [ $# -ge 1 ] ; then
	DISTRIBS=$@
else
	_version=$(($_version + 1))
fi
_id=`git -C ${HOME}/rmilter rev-parse --short HEAD` 

for d in $DISTRIBS ; do
	case $d in
	debian-jessie) REAL_DEPS="$DEPS dh-systemd" RULES_SED="-e 's/--with-systemd/--with-systemd --parallel/'" ;;
	debian-wheezy) REAL_DEPS="$DEPS" RULES_SED="-e 's/--with systemd/--parallel/' -e 's/-DWANT_SYSTEMD_UNITS=ON/-DWANT_SYSTEMD_UNITS=OFF/'" ;;
	ubuntu-*) 
		#chroot ${HOME}/$d /bin/sh -c "sed -e 's/main/main universe/' /etc/apt/sources.list > /tmp/.tt ; mv /tmp/.tt /etc/apt/sources.list"
		REAL_DEPS="$DEPS"
		RULES_SED="-e 's/--with systemd/--parallel/' -e 's/-DWANT_SYSTEMD_UNITS=ON/-DWANT_SYSTEMD_UNITS=OFF/'"
		;;
	*) REAL_DEPS="$DEPS" ;;
	esac
	
	_distname=`echo $d | sed -r -e 's/ubuntu-|debian-//'`
	_deps_line=`echo ${REAL_DEPS} | tr ' ' ','`
	chroot ${HOME}/$d sh -c "rm -fr rmilter-${RMILTER_VER} ; tar xvf rmilter-${RMILTER_VER}.tar.xz"
	chroot ${HOME}/$d sh -c "cp rmilter-${RMILTER_VER}.tar.xz rmilter_${RMILTER_VER}.orig.tar.xz"
	chroot ${HOME}/$d sh -c "sed -e \"s/Build-Depends:.*/Build-Depends: ${_deps_line}/\" -e \"s/Maintainer:.*/Maintainer: Vsevolod Stakhov <vsevolod@highsecure.ru>/\" < rmilter-${RMILTER_VER}/debian/control > /tmp/.tt ; mv /tmp/.tt rmilter-${RMILTER_VER}/debian/control"
	chroot ${HOME}/$d sh -c "sed -e \"s/unstable/${_distname}/\" -e \"s/Mikhail Gusarov <dottedmag@debian.org>/Vsevolod Stakhov <vsevolod@highsecure.ru>/\" -e \"s/1.6.3/${RMILTER_VER}-0~git${_version}~${_id}~${_distname}/\" < rmilter-${RMILTER_VER}/debian/changelog > /tmp/.tt ; mv /tmp/.tt rmilter-${RMILTER_VER}/debian/changelog"
	if [ -n "$RULES_SED" ] ; then
		chroot ${HOME}/$d sh -c "sed ${RULES_SED} < rmilter-${RMILTER_VER}/debian/rules > /tmp/.tt ; mv /tmp/.tt rmilter-${RMILTER_VER}/debian/rules"
	fi
	chroot ${HOME}/$d sh -c "sed -e 's/native/quilt/' < rmilter-${RMILTER_VER}/debian/source/format > /tmp/.tt ; mv /tmp/.tt rmilter-${RMILTER_VER}/debian/source/format"
	chroot ${HOME}/$d sh -c "cd rmilter-${RMILTER_VER} ; debuild -us -uc"

### i386 ###
	d="${d}-i386"
	chroot ${HOME}/$d sh -c "rm -fr rmilter-${RMILTER_VER} ; tar xvf rmilter-${RMILTER_VER}.tar.xz"
	chroot ${HOME}/$d sh -c "cp rmilter-${RMILTER_VER}.tar.xz rmilter_${RMILTER_VER}.orig.tar.xz"
	chroot ${HOME}/$d sh -c "sed -e \"s/Build-Depends:.*/Build-Depends: ${_deps_line}/\" -e \"s/Maintainer:.*/Maintainer: Vsevolod Stakhov <vsevolod@highsecure.ru>/\" < rmilter-${RMILTER_VER}/debian/control > /tmp/.tt ; mv /tmp/.tt rmilter-${RMILTER_VER}/debian/control"
	chroot ${HOME}/$d sh -c "sed -e \"s/unstable/${_distname}/\" -e \"s/Mikhail Gusarov <dottedmag@debian.org>/Vsevolod Stakhov <vsevolod@highsecure.ru>/\" -e \"s/1.6.3/${RMILTER_VER}-0~git${_version}~${_id}~${_distname}/\" < rmilter-${RMILTER_VER}/debian/changelog > /tmp/.tt ; mv /tmp/.tt rmilter-${RMILTER_VER}/debian/changelog"
	if [ -n "$RULES_SED" ] ; then
		chroot ${HOME}/$d sh -c "sed ${RULES_SED} < rmilter-${RMILTER_VER}/debian/rules > /tmp/.tt ; mv /tmp/.tt rmilter-${RMILTER_VER}/debian/rules"
	fi
	chroot ${HOME}/$d sh -c "sed -e 's/native/quilt/' < rmilter-${RMILTER_VER}/debian/source/format > /tmp/.tt ; mv /tmp/.tt rmilter-${RMILTER_VER}/debian/source/format"
	chroot ${HOME}/$d sh -c "cd rmilter-${RMILTER_VER} ; debuild -us -uc"
done

_id=`git -C ${HOME}/rspamd rev-parse --short HEAD` 

for d in $DISTRIBS ; do
	case $d in
	debian-jessie) REAL_DEPS="$DEPS dh-systemd libluajit-5.1-dev" RULES_SED="-e 's/--with-systemd/--with-systemd --parallel/'" ;;
	debian-wheezy) REAL_DEPS="$DEPS liblua5.1-dev" RULES_SED="-e 's/--with systemd/--parallel/' -e 's/-DWANT_SYSTEMD_UNITS=ON/-DWANT_SYSTEMD_UNITS=OFF/'" ;;
	ubuntu-*) 
		#chroot ${HOME}/$d /bin/sh -c "sed -e 's/main/main universe/' /etc/apt/sources.list > /tmp/.tt ; mv /tmp/.tt /etc/apt/sources.list"
		REAL_DEPS="$DEPS libluajit-5.1-dev"
		RULES_SED="-e 's/--with systemd/--parallel/' -e 's/-DWANT_SYSTEMD_UNITS=ON/-DWANT_SYSTEMD_UNITS=OFF/'"
		;;
	*) REAL_DEPS="$DEPS libluajit-5.1-dev" ;;
	esac
	
	_distname=`echo $d | sed -r -e 's/ubuntu-|debian-//'`
	_deps_line=`echo ${REAL_DEPS} | tr ' ' ','`
	chroot ${HOME}/$d sh -c "rm -fr rspamd-${RSPAMD_VER} ; tar xvf rspamd-${RSPAMD_VER}.tar.xz"
	chroot ${HOME}/$d sh -c "cp rspamd-${RSPAMD_VER}.tar.xz rspamd_${RSPAMD_VER}.orig.tar.xz"
	chroot ${HOME}/$d sh -c "sed -e \"s/Build-Depends:.*/Build-Depends: ${_deps_line}/\" -e \"s/Maintainer:.*/Maintainer: Vsevolod Stakhov <vsevolod@highsecure.ru>/\" < rspamd-${RSPAMD_VER}/debian/control > /tmp/.tt ; mv /tmp/.tt rspamd-${RSPAMD_VER}/debian/control"
	chroot ${HOME}/$d sh -c "sed -e \"s/unstable/${_distname}/\" -e \"s/Mikhail Gusarov <dottedmag@debian.org>/Vsevolod Stakhov <vsevolod@highsecure.ru>/\" -e \"s/0.9.4/${RSPAMD_VER}-0~git${_version}~${_id}~${_distname}/\" < rspamd-${RSPAMD_VER}/debian/changelog > /tmp/.tt ; mv /tmp/.tt rspamd-${RSPAMD_VER}/debian/changelog"
	if [ -n "$RULES_SED" ] ; then
		chroot ${HOME}/$d sh -c "sed ${RULES_SED} < rspamd-${RSPAMD_VER}/debian/rules > /tmp/.tt ; mv /tmp/.tt rspamd-${RSPAMD_VER}/debian/rules"
	fi
	chroot ${HOME}/$d sh -c "sed -e 's/native/quilt/' < rspamd-${RSPAMD_VER}/debian/source/format > /tmp/.tt ; mv /tmp/.tt rspamd-${RSPAMD_VER}/debian/source/format"
	chroot ${HOME}/$d sh -c "cd rspamd-${RSPAMD_VER} ; debuild -us -uc"
	chroot ${HOME}/$d sh -c "rm -fr rspamd-${RSPAMD_VER} ; tar xvf rspamd-${RSPAMD_VER}.tar.xz"

### i386 ###
	d="${d}-i386"
	chroot ${HOME}/$d sh -c "rm -fr rspamd-${RSPAMD_VER} ; tar xvf rspamd-${RSPAMD_VER}.tar.xz"
	chroot ${HOME}/$d sh -c "cp rspamd-${RSPAMD_VER}.tar.xz rspamd_${RSPAMD_VER}.orig.tar.xz"
	chroot ${HOME}/$d sh -c "sed -e \"s/Build-Depends:.*/Build-Depends: ${_deps_line}/\" -e \"s/Maintainer:.*/Maintainer: Vsevolod Stakhov <vsevolod@highsecure.ru>/\" < rspamd-${RSPAMD_VER}/debian/control > /tmp/.tt ; mv /tmp/.tt rspamd-${RSPAMD_VER}/debian/control"
	chroot ${HOME}/$d sh -c "sed -e \"s/unstable/${_distname}/\" -e \"s/Mikhail Gusarov <dottedmag@debian.org>/Vsevolod Stakhov <vsevolod@highsecure.ru>/\" -e \"s/0.9.4/${RSPAMD_VER}-0~git${_version}~${_id}~${_distname}/\" < rspamd-${RSPAMD_VER}/debian/changelog > /tmp/.tt ; mv /tmp/.tt rspamd-${RSPAMD_VER}/debian/changelog"
	if [ -n "$RULES_SED" ] ; then
		chroot ${HOME}/$d sh -c "sed ${RULES_SED} < rspamd-${RSPAMD_VER}/debian/rules > /tmp/.tt ; mv /tmp/.tt rspamd-${RSPAMD_VER}/debian/rules"
	fi
	chroot ${HOME}/$d sh -c "sed -e 's/native/quilt/' < rspamd-${RSPAMD_VER}/debian/source/format > /tmp/.tt ; mv /tmp/.tt rspamd-${RSPAMD_VER}/debian/source/format"
	chroot ${HOME}/$d sh -c "cd rspamd-${RSPAMD_VER} ; debuild -us -uc"
done
echo $_version > ${HOME}/version
