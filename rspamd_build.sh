#!/usr/bin/env bash

DEBIAN=1
RPM=1
ARM=1
FETCH_STAGE=0
BUILD_STAGE=0
SIGN_STAGE=0
UPLOAD_STAGE=0
DIST=0
NO_DELETE=0
LOG="./rspamd_build.log"
DOCKER_IMAGE="ghcr.io/rspamd/rspamd-build-docker"
CONFIG_FILE="./config.sh"

usage()
{
  printf "Rspamd build packages script\n"
  printf "\n"
  printf "./rspamd_build.sh\n"
  printf "\t-h --help\n"
  printf "\t--all: do all stages\n"
  printf "\t--deb: build debian packages\n"
  printf "\t--rpm: build rpm packages\n"
  printf "\t--stable: build stable packages\n"
  printf "\t--fetch: do fetch/git update step\n"
  printf "\t--build: do build step\n"
  printf "\t--sign: do sign step\n"
  printf "\t--upload: upload packages using ssh\n"
  printf "\t--upload-host: use the following upload host\n"
  printf "\t--no-inc: do not increase version for rolling release\n"
  printf "\t--no-delete: do not delete old files during rsync\n"
  printf "\t--no-arm: do not build aarch64 packages\n"
  printf "\t--dist: touch the specified dist only\n"
  printf "\t--config: use specific config instead of 'config.sh'\n"
  printf ""
}

while [ "$1" != "" ]; do
  PARAM=`echo $1 | awk -F= '{print $1}'`
  VALUE=`echo $1 | awk -F= '{print $2}'`
  case $PARAM in
    -h | --help)
      usage
      exit
      ;;
    --deb)
      DEBIAN=1
      ;;
    --no-deb)
      DEBIAN=0
      ;;
    --rpm)
      RPM=1
      ;;
    --no-rpm)
      RPM=0
      ;;
    --stable)
      export STABLE=1
      ;;
    --all)
      FETCH_STAGE=1
      BUILD_STAGE=1
      SIGN_STAGE=1
      UPLOAD_STAGE=1
      ;;
    --build)
      BUILD_STAGE=1
      ;;
    --fetch)
      FETCH_STAGE=1
      ;;
    --sign)
      SIGN_STAGE=1
      ;;
    --upload)
      UPLOAD_STAGE=1
      ;;
    --no-delete)
      NO_DELETE=1
      ;;
    --no-arm)
      ARM=0
      ;;
    --upload-host)
      UPLOAD_HOST="${VALUE}"
      ;;
    --dist)
      DIST=1
      DISTS="${VALUE}"
      ;;
    --config)
      CONFIG_FILE="${VALUE}"
      ;;
    *)
      echo "ERROR: unknown parameter \"$PARAM\""
      usage
      exit 1
      ;;
  esac
  shift
done

. ${CONFIG_FILE}

rm ${LOG} || true

get_rspamd() {
  HOST=$1
  $SSH_CMD $HOST rm -fr rspamd rspamd.build
  $SSH_CMD $HOST git clone --recursive ${GIT_REPO} rspamd

  if [ -n "${STABLE}" ] ; then
    $SSH_CMD $HOST "cd rspamd && git checkout ${RSPAMD_VER}"

    if [ $? -ne 0 ] ; then
      exit 1
    fi
    
    if [ -d "${PATCHES_DIR}"] ; then
      shopt -s nullglob
      for p in ${PATCHES_DIR}/* ; do
        echo "Applying patch $p"
        cat $p | $SSH_CMD $HOST "( cd rspamd && patch -p1 )"
        if [ $? -ne 0 ] ; then
          exit 1
        fi
      done
    fi
  fi
}


if [ $FETCH_STAGE -eq 1 ] ; then
  get_rspamd $SSH_HOST_X86
  if [ ${ARM} -ne 0 ] ; then
    get_rspamd $SSH_HOST_AARCH64
  fi
fi
gh_hash=`$SSH_CMD $SSH_HOST_X86 "cd rspamd ; git rev-parse --short HEAD"`

build_rspamd_deb() {
  HOST=$1
  DISTNAME=$2
  DISTVER=$3
  RSPAMD_REL=$4
  echo "Building rspamd-${RSPAMD_VER}-${RSPAMD_REL} for ${DISTNAME}-${DISTVER}"
  $SSH_CMD $HOST "rm -fr ./rspamd/build"
  $SSH_CMD $HOST "(cd ./rspamd && env CHANGELOG_NAME=\"Vsevolod Stakhov\" CHANGELOG_EMAIL=${MAINTAINER_EMAIL} ASAN=0 LUAJIT=1 DOCKER_IMAGE=\"${DISTNAME}-${DISTVER}\" DOCKER_REPO=\"${DOCKER_IMAGE}\" PRESERVE_ENVVARS=\"LUAJIT,ASAN\" \
    VERSION=${RSPAMD_VER} RELEASE=${RSPAMD_REL} OS=${DISTNAME} DIST=${DISTVER} ../packpack/packpack)" || { echo "Failed to build: rspamd-${RSPAMD_VER}-${RSPAMD_REL} for ${DISTNAME}-${DISTVER}" ; exit 1 ; }
  $SCP_CMD $HOST:rspamd/build/\*.deb ${TARGET_DIR}/${DISTNAME}-${DISTVER}/
  $SCP_CMD $HOST:rspamd/build/\*.dsc ${TARGET_DIR}/${DISTNAME}-${DISTVER}/
  $SCP_CMD $HOST:rspamd/build/\*changes ${TARGET_DIR}/${DISTNAME}-${DISTVER}/
  $SCP_CMD $HOST:rspamd/build/\*buildinfo ${TARGET_DIR}/${DISTNAME}-${DISTVER}/
  $SCP_CMD $HOST:rspamd/build/\*tar\* ${TARGET_DIR}/${DISTNAME}-${DISTVER}/
}

build_rspamd_rpm() {
  HOST=$1
  DISTNAME=$2
  DISTVER=$3
  RSPAMD_REL=$4
  $SSH_CMD $HOST "rm -fr ./rspamd/build"
  $SSH_CMD $HOST "(cd ./rspamd && env CHANGELOG_NAME=\"Vsevolod Stakhov\" CHANGELOG_EMAIL=${MAINTAINER_EMAIL} ASAN=0 LUAJIT=1 DOCKER_IMAGE=\"${DISTNAME}-${DISTVER}\" DOCKER_REPO=\"${DOCKER_IMAGE}\" PRESERVE_ENVVARS=\"LUAJIT,ASAN\" \
    VERSION=${RSPAMD_VER} RELEASE=${RSPAMD_REL} OS=${DISTNAME} DIST=${DISTVER} ../packpack/packpack)" || { echo "Failed to build: rspamd-${RSPAMD_VER}-${RSPAMD_REL} for ${DISTNAME}-${DISTVER}" ; exit 1 ; } 
  $SSH_CMD $HOST "(cd ./rspamd && env CHANGELOG_NAME=\"Vsevolod Stakhov\" CHANGELOG_EMAIL=${MAINTAINER_EMAIL} ASAN=1 LUAJIT=1 DOCKER_IMAGE=\"${DISTNAME}-${DISTVER}\" DOCKER_REPO=\"${DOCKER_IMAGE}\" PRESERVE_ENVVARS=\"LUAJIT,ASAN\" \
    VERSION=${RSPAMD_VER} RELEASE=${RSPAMD_REL} OS=${DISTNAME} DIST=${DISTVER} ../packpack/packpack)" || { echo "Failed to build: rspamd-${RSPAMD_VER}-${RSPAMD_REL} for ${DISTNAME}-${DISTVER}" ; exit 1 ; }
  $SCP_CMD $HOST:rspamd/build/\*.rpm ${TARGET_DIR}/${DISTNAME}-${DISTVER}/
}


if [ ${DIST} -ne 0 ] ; then
  _found=0
  DEBIAN=0
  RPM=0
  _DISTRIBS_DEB=${DISTRIBS_DEB}
  DISTRIBS_DEB=""
  for d in ${_DISTRIBS_DEB} ; do
    if [ "$d" = "${DISTS}" ] ; then
      DEBIAN=1
      DISTRIBS_DEB="$d"
      _found=1
    fi
  done
  _DISTRIBS_RPM=${DISTRIBS_RPM}
  DISTRIBS_RPM=""
  for d in ${_DISTRIBS_RPM} ; do
    if [ "$d" = "${DISTS}" ] ; then
      RPM=1
      DISTRIBS_RPM="$d"
      _found=1
    fi
  done

  if [ $_found -eq 0 ] ; then
    echo "Unknown --dist: $DISTS"
    exit 1
  fi
fi

if [ $BUILD_STAGE -eq 1 ] ; then
  mkdir -p ${TARGET_DIR}
  if [ -n "${STABLE}" ] ; then
    _version="${STABLE_VER}"
  else
    _version=`cat ./version || echo 0`
    if [ $# -ge 1 ] ; then
      DISTRIBS=$@
    else
      _version=$(($_version + 1))
    fi
  fi

  for d in $DISTRIBS_DEB ; do
    _distro=`echo $d | cut -d'-' -f 1`
    _ver=`echo $d | cut -d'-' -f 2`
    if [ -n "${STABLE}" ] ; then
      pkg_version="${_version}~${gh_hash}~$_ver"
    else
      pkg_version="0~git${_version}~${gh_hash}~$_ver"
    fi
    mkdir -p ${TARGET_DIR}/${_distro}-${_ver}
    rm -f ${TARGET_DIR}/${_distro}-${_ver}/*.deb
    rm -f ${TARGET_DIR}/${_distro}-${_ver}/*.dsc
    rm -f ${TARGET_DIR}/${_distro}-${_ver}/*changes
    rm -f ${TARGET_DIR}/${_distro}-${_ver}/*buildinfo
    rm -f ${TARGET_DIR}/${_distro}-${_ver}/*tar*
    build_rspamd_deb $SSH_HOST_X86 $_distro $_ver $pkg_version
    if [ ${ARM} -ne 0 ] ; then
      echo $ARM_BLACKLIST | grep $d > /dev/null
      if [ $? -ne 0 ] ; then
        build_rspamd_deb $SSH_HOST_AARCH64 $_distro $_ver $pkg_version
      fi
    fi

  done
  for d in $DISTRIBS_RPM ; do    
    _distro=`echo $d | cut -d'-' -f 1`
    _ver=`echo $d | cut -d'-' -f 2`
    if [ -n "${STABLE}" ] ; then
      pkg_version="${_version}"
    else
      pkg_version="${_version}.git${gh_hash}"
    fi
    mkdir -p ${TARGET_DIR}/${_distro}-${_ver} ; rm -f ${TARGET_DIR}/${_distro}-${_ver}/*.rpm
    build_rspamd_rpm $SSH_HOST_X86 $_distro $_ver $pkg_version
    if [ ${ARM} -ne 0 ] ; then
      echo $ARM_BLACKLIST | grep $d > /dev/null
      if [ $? -ne 0 ] ; then
        build_rspamd_rpm $SSH_HOST_AARCH64 $_distro $_ver $pkg_version
      fi
    fi
  done


  # Increase version
  if [ -z "${STABLE}" -a -z "${NO_INC}" ] ; then
    echo $_version > ./version
  fi
fi

if [ ${SIGN_STAGE} -eq 1 ] ; then

  if [ -n "${STABLE}" ] ; then
    _version="${STABLE_VER}"
  else
    _version=`cat ./version || echo 0`
  fi

  if [ $DEBIAN -ne 0 ] ; then
    mkdir -p ${TARGET_DIR}/repos/
    rm -fr ${TARGET_DIR}/repos/*
    gpg --armor --output ${TARGET_DIR}/repos/rspamd.asc --export $KEY
    mkdir ${TARGET_DIR}/repos/conf || true

    for d in $DISTRIBS_DEB ; do
      _distname=`echo $d | sed -r -e 's/ubuntu-|debian-//'`
      if [ -n "${STABLE}" ] ; then
        _pkg_ver="${RSPAMD_VER}-${STABLE_VER}~${gh_hash}~${_distname}"
        _repo_descr="Apt repository for rspamd stable builds"
      else
        _pkg_ver="${RSPAMD_VER}-0~git${_version}~${gh_hash}~${_distname}"
        _repo_descr="Apt repository for rspamd nightly builds"
      fi
      ARCHS="source amd64"
      if [ $ARM -ne 0 ] ; then
        ARCHS="${ARCHS} arm64"
      fi
      _repodir=${TARGET_DIR}/repos/
      cat >> $_repodir/conf/distributions <<EOD
Origin: Rspamd
Label: Rspamd
Codename: ${_distname}
Architectures: ${ARCHS}
Components: main
Description: ${_repo_descr}
SignWith: ${KEY}

EOD
      dpkg-sig -k $KEY --batch=1 --sign builder ${TARGET_DIR}/$d/rspamd_${_pkg_ver}*.deb
      dpkg-sig -k $KEY --batch=1 --sign builder ${TARGET_DIR}/$d/rspamd-asan_${_pkg_ver}*.deb
      dpkg-sig -k $KEY --batch=1 --sign builder ${TARGET_DIR}/$d/rspamd-dbg_${_pkg_ver}*.deb
      dpkg-sig -k $KEY --batch=1 --sign builder ${TARGET_DIR}/$d/rspamd-asan-dbg_${_pkg_ver}*.deb
      debsign --re-sign -k $KEY ${TARGET_DIR}/$d/rspamd_${_pkg_ver}*.changes
      reprepro  -P extra -S mail -b $_repodir -v --keepunreferencedfiles includedeb $_distname ${TARGET_DIR}/$d/rspamd_${_pkg_ver}_amd64.deb
      reprepro  -P extra -S debug -b $_repodir -v --keepunreferencedfiles includedeb $_distname ${TARGET_DIR}/$d/rspamd-dbg_${_pkg_ver}_amd64.deb
      reprepro  -P extra -S mail -b $_repodir -v --keepunreferencedfiles includedeb $_distname ${TARGET_DIR}/$d/rspamd-asan_${_pkg_ver}_amd64.deb
      reprepro  -P extra -S debug -b $_repodir -v --keepunreferencedfiles includedeb $_distname ${TARGET_DIR}/$d/rspamd-asan-dbg_${_pkg_ver}_amd64.deb
      if [ $ARM -ne 0 ] ; then
        echo $ARM_BLACKLIST | grep $d > /dev/null
        if [ $? -ne 0 ] ; then
          reprepro  -P extra -S mail -b $_repodir -v --keepunreferencedfiles includedeb $_distname ${TARGET_DIR}/$d/rspamd_${_pkg_ver}_arm64.deb
          reprepro  -P extra -S debug -b $_repodir -v --keepunreferencedfiles includedeb $_distname ${TARGET_DIR}/$d/rspamd-dbg_${_pkg_ver}_arm64.deb
          reprepro  -P extra -S mail -b $_repodir -v --keepunreferencedfiles includedeb $_distname ${TARGET_DIR}/$d/rspamd-asan_${_pkg_ver}_arm64.deb
          reprepro  -P extra -S debug -b $_repodir -v --keepunreferencedfiles includedeb $_distname ${TARGET_DIR}/$d/rspamd-asan-dbg_${_pkg_ver}_arm64.deb
        fi
      fi
      reprepro  -P extra -S mail -b $_repodir -v --keepunreferencedfiles includedsc $_distname ${TARGET_DIR}/$d/rspamd_${_pkg_ver}.dsc

      gpg -u 0x$KEY -sb $_repodir/dists/$_distname/Release && \
        mv $_repodir/dists/$_distname/Release.sig $_repodir/dists/$_distname/Release.gpg
    done
  fi # DEBIAN == 0

  if [ $RPM -ne 0 ] ; then
    mkdir -p ${TARGET_DIR}/rpm
    rm -f ${TARGET_DIR}/rpm/rspamd.asc || true
    gpg --armor --output ${TARGET_DIR}/rpm/rspamd.asc --export $KEY

    for d in $DISTRIBS_RPM ; do
      for ARCH in x86_64 aarch64 ; do
        find ${TARGET_DIR}/$d -name \*${ARCH}.rpm | grep . > /dev/null
        if [ $? -eq 0 ] ; then
          rm -fr ${TARGET_DIR}/rpm/$d/${ARCH} || true
          mkdir -p ${TARGET_DIR}/rpm/$d/${ARCH}
          cp ${TARGET_DIR}/$d/*${ARCH}.rpm ${TARGET_DIR}/rpm/$d/$ARCH/
          for p in `find ${TARGET_DIR}/rpm/$d/ -name \*${ARCH}.rpm` ; do
            ./rpm_sign.expect $p
          done
          (cd ${TARGET_DIR}/rpm/$d/${ARCH} && createrepo --compress-type gz . )

          gpg --default-key ${KEY} --detach-sign --armor \
            ${TARGET_DIR}/rpm/$d/${ARCH}/repodata/repomd.xml
        fi
      done

      if [ -n "${STABLE}" ] ; then
        cat <<EOD > ${TARGET_DIR}/rpm/$d/rspamd.repo
[rspamd]
name=Rspamd stable repository
baseurl=http://rspamd.com/rpm-stable/$d/\$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=http://rspamd.com/rpm/rspamd.asc
EOD
      else
        cat <<EOD > ${TARGET_DIR}/rpm/$d/rspamd-experimental.repo
[rspamd-experimental]
name=Rspamd experimental repository
baseurl=http://rspamd.com/rpm/$d/\$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=http://rspamd.com/rpm/rspamd.asc
EOD
      fi

    done
  fi # RPM == 0
fi

RSYNC_ARGS="-rup"

if [ $DIST -eq 0 ] ; then
  if [ ${NO_DELETE} -eq 0 ] ; then
    if [ $RPM -eq 1 -a $DEBIAN -eq 1 ] ; then
      RSYNC_ARGS="${RSYNC_ARGS} --delete --delete-before"
    fi
  fi
fi

if [ ${UPLOAD_STAGE} -eq 1 ] ; then
  if [ -z "${UPLOAD_HOST}" ] ; then
    echo "No UPLOAD_HOST specified, exiting"
    exit 1
  fi

  if [ $DEBIAN -ne 0 ] ; then
    if [ -n "${STABLE}" ] ; then
      rsync -e "ssh -i ${SSH_KEY_DEB_STABLE}" ${RSYNC_ARGS} \
        ${TARGET_DIR}/repos/* ${UPLOAD_HOST}:${UPLOAD_SUFFIX}${TARGET_DEB_STABLE}
    else
      rsync -e "ssh -i ${SSH_KEY_DEB_UNSTABLE}" ${RSYNC_ARGS} \
        ${TARGET_DIR}/repos/* ${UPLOAD_HOST}:${UPLOAD_SUFFIX}${TARGET_DEB_UNSTABLE}
    fi
  fi

  if [ $RPM -ne 0 ] ; then
    for d in $DISTRIBS_RPM ; do
      if [ -n "${STABLE}" ] ; then
        rsync -e "ssh -i ${SSH_KEY_RPM_STABLE}" ${RSYNC_ARGS} \
          ${TARGET_DIR}/rpm/$d/* ${UPLOAD_HOST}:${UPLOAD_SUFFIX}${TARGET_RPM_STABLE}/$d/
      else
        rsync -e "ssh -i ${SSH_KEY_RPM_UNSTABLE}" ${RSYNC_ARGS} \
          ${TARGET_DIR}/rpm/$d/* ${UPLOAD_HOST}:${UPLOAD_SUFFIX}${TARGET_RPM_UNSTABLE}/$d/
      fi
    done
  fi
fi
