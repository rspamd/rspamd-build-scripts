#!/bin/sh

DISTRIBS="centos-6 centos-7 fedora-21 fedora-22"
RSPAMD_VER="1.0.0"
RMILTER_VER="1.6.4"
BUILD_DIR="/build-cEWitUrAiCErmOTatORonDUREversLaNgORNmiNglebroveNodemBLepLAnkTiCkANDAnIfy/"
RSPAMD_VER="1.0.0"
RMILTER_VER="1.6.4"
KEY="3EF4A6C1"
ARCH="x86_64"
SSH_KEY="${HOME}/.ssh/identity.repo-rpm"
SSH_TARGET=${SSH_TARGET:-""}
export DEBIAN_FRONTEND="noninteractive"
export LANG="C"

rm -f ${HOME}/rpm/gpg.key || true
gpg --armor --output ${HOME}/rpm/gpg.key --export $KEY
for d in $DISTRIBS ; do
	rm -fr ${HOME}/rpm/$d/ || true
	mkdir -p ${HOME}/rpm/$d/${ARCH} || true
	cp ${HOME}/${d}/${BUILD_DIR}/RPMS/${ARCH}/*.rpm ${HOME}/rpm/$d/${ARCH}
	for p in ${HOME}/rpm/$d/${ARCH}/*.rpm ; do
		./rpm_sign.expect $p
	done
	(cd ${HOME}/rpm/$d/${ARCH} && createrepo --compress-type gz . )

	gpg --default-key ${KEY} --detach-sign --armor ${HOME}/rpm/$d/${ARCH}/repodata/repomd.xml

	cat <<EOD > ${HOME}/rpm/$d/rspamd-experimental.repo
[rspamd-experimental]
name=Rspamd experimental repository
baseurl=http://rspamd.com/rpm/$d/${ARCH}/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=http://rspamd.com/rpm/gpg.key
EOD
done

scp -r -i ${SSH_KEY} ${HOME}/rpm/* ${SSH_TARGET}
