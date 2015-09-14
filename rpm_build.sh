#!/bin/sh

DISTRIBS="centos-6 centos-7 fedora-21 fedora-22"
RSPAMD_VER="1.0.0"
RMILTER_VER="1.6.4"
BUILD_DIR="/build-cEWitUrAiCErmOTatORonDUREversLaNgORNmiNglebroveNodemBLepLAnkTiCkANDAnIfy/"
VERSION=`cat ${HOME}/rpm_version || echo 0`

DEPS="glib2-devel libevent-devel openssl-devel pcre-devel perl hiredis-devel cmake rpm-build gmime-devel gcc make sendmail-devel"
export DEBIAN_FRONTEND="noninteractive"
export LANG="C"

if [ $# -ge 1 ] ; then
    DISTRIBS=$@
else
    _version=$(($_version + 1))
fi
_id_rmilter=`git -C ${HOME}/rmilter rev-parse --short HEAD`
_id_rspamd=`git -C ${HOME}/rspamd rev-parse --short HEAD`

for d in $DISTRIBS ; do
	echo "***** BUILDING FOR ${d} *********"
    case $d in
    opensuse-*)
        REAL_DEPS="$DEPS lua-devel sqlite-devel"
		YUM="zypper -n"
        ;;
	fedora-22*)
        REAL_DEPS="$DEPS luajit-devel sqlite-devel libopendkim-devel"
		YUM="dnf -y"
		;;
	fedora-21*)
        REAL_DEPS="$DEPS luajit-devel sqlite-devel libopendkim-devel"
		YUM="yum -y"
		;;
	centos-6)
        REAL_DEPS="$DEPS lua-devel sqlite-devel opendkim-devel"
		YUM="yum -y"
		;;
	centos-7)
        REAL_DEPS="$DEPS luajit-devel sqlite-devel opendkim-devel"
		YUM="yum -y"
		;;
    *) 
		YUM="yum -y"
		REAL_DEPS="$DEPS sqlite-devel luajit-devel" ;;
    esac
	
	cp ${HOME}/rpm/SPECS/rspamd.spec ${HOME}/$d/${BUILD_DIR}/SPECS
	cp ${HOME}/rpm/SPECS/rmilter.spec ${HOME}/$d/${BUILD_DIR}/SPECS

	# Build rmilter
	sed -e "s/^Release: [0-9]*$/Release: ${VERSION}.git${_id_rmilter}/" < ${HOME}/$d/${BUILD_DIR}/SPECS/rmilter.spec > /tmp/.tt
	mv /tmp/.tt ${HOME}/$d/${BUILD_DIR}/SPECS/rmilter.spec
	chroot ${HOME}/$d rpmbuild  --define='jobs 4' --define='BuildRoot %{_tmppath}/%{name}' --define="_topdir ${BUILD_DIR}" -ba ${BUILD_DIR}/SPECS/rmilter.spec
	# Build rspamd
	sed -e "s/^Release: [0-9]*$/Release: ${VERSION}.git${_id_rspamd}/" < ${HOME}/$d/${BUILD_DIR}/SPECS/rspamd.spec > /tmp/.tt
	mv /tmp/.tt ${HOME}/$d/${BUILD_DIR}/SPECS/rspamd.spec
	chroot ${HOME}/$d rpmbuild  --define='jobs 4' --define='BuildRoot %{_tmppath}/%{name}' --define="_topdir ${BUILD_DIR}" -ba ${BUILD_DIR}/SPECS/rspamd.spec
	echo "***** COMPLETED BUILD FOR ${d} *********"
done

if [ $# -eq 0 ] ; then
	echo $(( ${VERSION} + 1 )) > ${HOME}/rpm_version
fi
