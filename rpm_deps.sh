#!/bin/sh

DISTRIBS="centos-6 centos-7 fedora-21 fedora-22"
RSPAMD_VER="1.0.0"
RMILTER_VER="1.6.4"
BUILD_DIR="/build-cEWitUrAiCErmOTatORonDUREversLaNgORNmiNglebroveNodemBLepLAnkTiCkANDAnIfy/"

DEPS="glib2-devel libevent-devel openssl-devel pcre-devel perl hiredis-devel cmake rpm-build gmime-devel gcc make sendmail-devel bison flex"
export DEBIAN_FRONTEND="noninteractive"
export LANG="C"

rm -fr ${HOME}/rspamd ${HOME}/rspamd.build ${HOME}/rmilter ${HOME}/rmilter.build
/usr/bin/git clone --recursive https://github.com/vstakhov/rspamd ${HOME}/rspamd
/usr/bin/git clone --recursive https://github.com/vstakhov/rmilter ${HOME}/rmilter
( mkdir ${HOME}/rspamd.build ; cd ${HOME}/rspamd.build ; cmake ${HOME}/rspamd ; make dist )
( mkdir ${HOME}/rmilter.build ; cd ${HOME}/rmilter.build ; cmake ${HOME}/rmilter ; make dist )

for d in $DISTRIBS ; do
	echo "***** UPDATING ${d} *********"
    case $d in
    opensuse-*)
        #chroot ${HOME}/$d /bin/sh -c "sed -e 's/main/main universe/' /etc/apt/sources.list > /tmp/.tt ; mv /tmp/.tt /etc/apt/sources.list"
        REAL_DEPS="$DEPS lua-devel sqlite-devel"
		YUM="zypper -n"
        ;;
	fedora-22*)
        REAL_DEPS="$DEPS luajit-devel sqlite-devel libopendkim-devel"
		YUM="dnf --nogpgcheck -y"
		;;
	fedora-21*)
        REAL_DEPS="$DEPS luajit-devel sqlite-devel libopendkim-devel"
		YUM="yum -y"
		;;
	centos-6)
        REAL_DEPS="$DEPS lua-devel sqlite-devel libopendkim-devel"
		YUM="yum -y"
		;;
	centos-7)
        REAL_DEPS="$DEPS luajit-devel sqlite-devel libopendkim-devel"
		YUM="yum -y"
		;;
    *) 
		YUM="yum -y"
		REAL_DEPS="$DEPS sqlite-devel luajit-devel" ;;
    esac

    chroot ${HOME}/$d ${YUM} update
    chroot ${HOME}/$d ${YUM} install ${REAL_DEPS}
    cp ${HOME}/rspamd.build/rspamd-${RSPAMD_VER}.tar.xz ${HOME}/$d
    cp ${HOME}/rmilter.build/rmilter-${RMILTER_VER}.tar.xz ${HOME}/$d

	chroot ${HOME}/$d rm -fr ${BUILD_DIR}
	chroot ${HOME}/$d mkdir ${BUILD_DIR} \
		${BUILD_DIR}/RPMS \
		${BUILD_DIR}/RPMS/i386 \
		${BUILD_DIR}/RPMS/x86_64 \
		${BUILD_DIR}/SOURCES \
		${BUILD_DIR}/SPECS \
		${BUILD_DIR}/SRPMS
	cp ${HOME}/rpm/SPECS/rspamd.spec ${HOME}/$d/${BUILD_DIR}/SPECS
	cp ${HOME}/rpm/SPECS/rmilter.spec ${HOME}/$d/${BUILD_DIR}/SPECS
	cp ${HOME}/rspamd.build/rspamd-${RSPAMD_VER}.tar.xz ${HOME}/$d/${BUILD_DIR}/SOURCES
    cp ${HOME}/rmilter.build/rmilter-${RMILTER_VER}.tar.xz ${HOME}/$d/${BUILD_DIR}/SOURCES
	cp ${HOME}/rpm/SOURCES/* ${HOME}/$d/${BUILD_DIR}/SOURCES
done
