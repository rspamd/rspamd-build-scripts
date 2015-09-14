#!/bin/sh

DISTRIBS="ubuntu-precise
		ubuntu-trusty
		ubuntu-vivid
		debian-jessie
		debian-wheezy"
RSPAMD_VER="1.0.0"
RMILTER_VER="1.6.4"
KEY="3EF4A6C1"
SSH_KEY="${HOME}/.ssh/identity.repo"
SSH_TARGET=${SSH_TARGET:-""}

export DEBIAN_FRONTEND="noninteractive"
export LANG="C"

_version=`cat ${HOME}/version || echo 0`
_id=`git -C ${HOME}/rspamd rev-parse --short HEAD`
_rmilter_id=`git -C ${HOME}/rmilter rev-parse --short HEAD`
rm -fr ${HOME}/repos/*
gpg --armor --output ${HOME}/repos/gpg.key --export $KEY
mkdir ${HOME}/repos/conf || true
for d in $DISTRIBS ; do
	_distname=`echo $d | sed -r -e 's/ubuntu-|debian-//'`
	_pkg_ver="${RSPAMD_VER}-0~git${_version}~${_id}~${_distname}"
	_rmilter_pkg_ver="${RMILTER_VER}-0~git${_version}~${_rmilter_id}~${_distname}"
	_distname=`echo $d | sed -r -e 's/ubuntu-|debian-//'`
	_repodir=${HOME}/repos/
cat >> $_repodir/conf/distributions <<EOD
Origin: Rspamd
Label: Rspamd
Codename: $_distname
Architectures:  source amd64 i386
Components: main
Description: Apt repository for rspamd nightly builds
SignWith: ${KEY}

EOD
	dpkg-sig -k $KEY --batch=1 --sign builder ${HOME}/$d/rspamd_${_pkg_ver}*.deb
	debsign --re-sign -k $KEY ${HOME}/$d/rspamd_${_pkg_ver}*.changes
	dpkg-sig -k $KEY --batch=1 --sign builder ${HOME}/$d/rmilter_${_rmilter_pkg_ver}*.deb
	debsign --re-sign -k $KEY ${HOME}/$d/rmilter_${_rmilter_pkg_ver}*.changes
	reprepro -b $_repodir -v --keepunreferencedfiles includedeb $_distname $d/rspamd_${_pkg_ver}_amd64.deb
	reprepro -b $_repodir -v --keepunreferencedfiles includedsc $_distname $d/rspamd_${_pkg_ver}.dsc
	reprepro -b $_repodir -v --keepunreferencedfiles includedeb $_distname $d/rmilter_${_rmilter_pkg_ver}_amd64.deb
	reprepro -b $_repodir -v --keepunreferencedfiles includedsc $_distname $d/rmilter_${_rmilter_pkg_ver}.dsc
### i386 ###
	d="${d}-i386"
	dpkg-sig -k $KEY --batch=1 --sign builder ${HOME}/$d/rspamd_${_pkg_ver}*.deb
	debsign --re-sign -k $KEY ${HOME}/$d/rspamd_${_pkg_ver}*.changes
	dpkg-sig -k $KEY --batch=1 --sign builder ${HOME}/$d/rmilter_${_rmilter_pkg_ver}*.deb
	debsign --re-sign -k $KEY ${HOME}/$d/rmilter_${_rmilter_pkg_ver}*.changes
	reprepro -b $_repodir -v --keepunreferencedfiles includedeb $_distname $d/rspamd_${_pkg_ver}_i386.deb
	reprepro -b $_repodir -v --keepunreferencedfiles includedeb $_distname $d/rmilter_${_rmilter_pkg_ver}_i386.deb

	gpg -u 0x$KEY -sb $_repodir/dists/$_distname/Release && mv $_repodir/dists/$_distname/Release.sig $_repodir/dists/$_distname/Release.gpg
done

scp -r -i ${SSH_KEY} ${HOME}/repos/* ${SSH_TARGET}
