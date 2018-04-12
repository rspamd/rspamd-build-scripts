#!/bin/sh

export DEPS_DEB="fakeroot make ca-certificates less git vim devscripts debhelper \
  dpkg-dev cmake libevent-dev libglib2.0-dev libgmime-2.6-dev libpcre3-dev \
  libssl-dev libcurl4-openssl-dev libsqlite3-dev perl libopendkim-dev \
  libmilter-dev bison flex libmagic-dev git ragel libfann-dev libjemalloc-dev libmemcached-dev ragel libicu-dev"
export DISTRIBS_DEB="ubuntu-trusty \
  ubuntu-xenial \
  ubuntu-bionic \
  debian-jessie \
  debian-stretch \
  debian-sid"
export DISTRIBS_RPM="centos-6 centos-7"
export DEPS_RPM="glib2-devel libevent-devel openssl-devel pcre-devel perl \
  hiredis-devel cmake rpm-build gmime-devel gcc make sendmail-devel bison \
  flex file-devel fann-devel git rsync perl-Digest-MD5 libmemcached-devel ragel perl-Digest-MD5 gd-devel libicu-devel jemalloc-devel"

export MAIN_ARCH="x86_64"
export RSPAMD_VER_UNSTABLE="1.7.4"
export RSPAMD_VER_STABLE="1.7.3"
export RMILTER_VER_UNSTABLE="2.0.0"
export RMILTER_VER_STABLE="1.10.0"
# RPM stupidity
export BUILD_DIR="/build7558b18c49c3aede6aa20ecb0513b9eb2b39ce7db0c739ec006369009fdf893d91b9ec4199fa64acd80aa1de7fac87a148a6f65e98f258b455996c5f99d990d2"

if [ -n "${STABLE}" ] ; then
  export RSPAMD_VER="${RSPAMD_VER_STABLE}"
  export RMILTER_VER="${RMILTER_VER_STABLE}"
  export STABLE_VER="1"
else
  export RSPAMD_VER="${RSPAMD_VER_UNSTABLE}"
  export RMILTER_VER="${RMILTER_VER_UNSTABLE}"
fi

export KEY="3EF4A6C1"
export TARGET_DEB_STABLE="rspamd.com/apt-stable"
export TARGET_DEB_UNSTABLE="rspamd.com/apt"
export TARGET_RPM_STABLE="rspamd.com/rpm-stable"
export TARGET_RPM_UNSTABLE="rspamd.com/rpm"
export SSH_KEY_DEB_STABLE="${HOME}/.ssh/identity.repo-deb-stable"
export SSH_KEY_DEB_UNSTABLE="${HOME}/.ssh/identity.repo-deb-unstable"
export SSH_KEY_RPM_STABLE="${HOME}/.ssh/identity.repo-rpm-stable"
export SSH_KEY_RPM_UNSTABLE="${HOME}/.ssh/identity.repo-rpm-unstable"

if [ -f "./config.local.sh" ] ; then
  . ./config.local.sh
fi
