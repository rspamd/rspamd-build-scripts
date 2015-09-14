#!/bin/sh

DISTRIBS="ubuntu-precise
		ubuntu-trusty
		ubuntu-vivid
		debian-jessie
		debian-wheezy"
RSPAMD_VER="1.0.0"
RMILTER_VER="1.6.4"

DEPS="fakeroot make ca-certificates less git vim devscripts debhelper dpkg-dev cmake libevent-dev libglib2.0-dev libgmime-2.6-dev libpcre3-dev libssl-dev libcurl4-openssl-dev libhiredis-dev libsqlite3-dev perl libopendkim-dev libmilter-dev libspf2-dev bison flex"
export DEBIAN_FRONTEND="noninteractive"
export LANG="C"

rm -fr ${HOME}/rspamd ${HOME}/rspamd.build ${HOME}/rmilter ${HOME}/rmilter.build
/usr/bin/git clone --recursive https://github.com/vstakhov/rspamd ${HOME}/rspamd
/usr/bin/git clone --recursive https://github.com/vstakhov/rmilter ${HOME}/rmilter
( mkdir ${HOME}/rspamd.build ; cd ${HOME}/rspamd.build ; cmake ${HOME}/rspamd ; make dist ) 
( mkdir ${HOME}/rmilter.build ; cd ${HOME}/rmilter.build ; cmake ${HOME}/rmilter ; make dist ) 

for d in $DISTRIBS ; do
	case $d in
	debian-jessie) REAL_DEPS="$DEPS dh-systemd libluajit-5.1-dev" ;;
	debian-wheezy) REAL_DEPS="$DEPS liblua5.1-dev" ;;
	ubuntu-*) 
		#chroot ${HOME}/$d /bin/sh -c "sed -e 's/main/main universe/' /etc/apt/sources.list > /tmp/.tt ; mv /tmp/.tt /etc/apt/sources.list"
		REAL_DEPS="$DEPS libluajit-5.1-dev" 
		;;
	*) REAL_DEPS="$DEPS libluajit-5.1-dev" ;;
	esac

	chroot ${HOME}/$d "/usr/bin/apt-get" update
	chroot ${HOME}/$d "/usr/bin/apt-get" install -y --no-install-recommends ${REAL_DEPS}
	cp ${HOME}/rspamd.build/rspamd-${RSPAMD_VER}.tar.xz ${HOME}/$d/
	cp ${HOME}/rmilter.build/rmilter-${RMILTER_VER}.tar.xz ${HOME}/$d/

### i386 ###
	d="$d-i386"
	chroot ${HOME}/$d "/usr/bin/apt-get" update
	chroot ${HOME}/$d "/usr/bin/apt-get" install -y --no-install-recommends ${REAL_DEPS}
	cp ${HOME}/rspamd.build/rspamd-${RSPAMD_VER}.tar.xz ${HOME}/$d/
	cp ${HOME}/rmilter.build/rmilter-${RMILTER_VER}.tar.xz ${HOME}/$d/
done
