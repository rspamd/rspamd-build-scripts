#!/bin/sh

export DEPS_DEB="fakeroot make ca-certificates less vim devscripts debhelper \
  dpkg-dev cmake libevent-dev libglib2.0-dev libpcre2-dev libjemalloc-dev \
  libssl-dev libcurl4-openssl-dev libsqlite3-dev perl \
  libmagic-dev git ragel libicu-dev curl libsodium-dev build-essential liblua5.1-dev"
export DISTRIBS_DEB="ubuntu-bionic \
  ubuntu-focal \
  ubuntu-jammy \
  debian-buster \
  debian-bullseye"
export DISTRIBS_RPM="centos-7 centos-8"
export DEPS_RPM="glib2-devel openssl-devel pcre-devel perl \
  cmake rpm-build gcc make \
  file-devel git rsync perl-Digest-MD5  libicu-devel libunwind-devel curl"

export MAIN_ARCH="x86_64"
export RSPAMD_VER_UNSTABLE="3.3"
export RSPAMD_VER_STABLE="3.2"
# RPM stupidity
export BUILD_DIR="/build7558b18c49c3aede6aa20ecb0513b9eb2b39ce7db0c739ec006369009fdf893d91b9ec4199fa64acd80aa1de7fac87a148a6f65e98f258b455996c5f99d990d2"

if [ -n "${STABLE}" ] ; then
  export RSPAMD_VER="${RSPAMD_VER_STABLE}"
  export STABLE_VER="1"
else
  export RSPAMD_VER="${RSPAMD_VER_UNSTABLE}"
fi

export KEY="3FA347D5E599BE4595CA2576FFA232EDBF21E25E"
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
