#!/bin/sh

export DISTRIBS_DEB="ubuntu-focal \
  ubuntu-jammy \
  debian-bullseye \
  debian-bookworm"
export DISTRIBS_RPM="centos-7 centos-8 centos-9"
# Old distributives that are just broken on aarch64 (e.g. old libc++)
export ARM_BLACKLIST="ubuntu-bionic debian-buster"

# Can be overriden (e.g. adding a username)
export SSH_CMD="ssh"
export SCP_CMD="scp"
export TARGET_DIR="./out"
export MAINTAINER_EMAIL="vsevolod@rspamd.com"

# From old upload system (should be refactored one day)
export TARGET_DEB_STABLE="apt-stable"
export TARGET_DEB_UNSTABLE="apt"
export TARGET_RPM_STABLE="rpm-stable"
export TARGET_RPM_UNSTABLE="rpm"
export SSH_KEY_DEB_STABLE="${HOME}/.ssh/identity.repo-deb-stable"
export SSH_KEY_DEB_UNSTABLE="${HOME}/.ssh/identity.repo-deb-unstable"
export SSH_KEY_RPM_STABLE="${HOME}/.ssh/identity.repo-rpm-stable"
export SSH_KEY_RPM_UNSTABLE="${HOME}/.ssh/identity.repo-rpm-unstable"
export UPLOAD_SUFFIX="rspamd.com/dist/"

# Must be overriden
export SSH_HOST_X86="example.com"
export SSH_HOST_AARCH64="example.com"

export RSPAMD_VER_UNSTABLE="3.9.0"
export RSPAMD_VER_STABLE="3.8.4"

if [ -n "${STABLE}" ] ; then
  export RSPAMD_VER="${RSPAMD_VER_STABLE}"
  export STABLE_VER="1"
else
  export RSPAMD_VER="${RSPAMD_VER_UNSTABLE}"
fi

export KEY="3FA347D5E599BE4595CA2576FFA232EDBF21E25E"

if [ -f "./config.local.sh" ] ; then
  . ./config.local.sh
fi
