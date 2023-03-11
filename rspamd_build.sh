#!/usr/bin/env bash

DEBIAN=1
RPM=1
BUILD_STAGE=0
SIGN_STAGE=0
UPLOAD_STAGE=0
UPLOAD_SUFFIX="dist/"
LOG="./rspamd_build.log"

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
  printf "\t--build: do build step\n"
  printf "\t--sign: do sign step\n"
  printf "\t--upload: upload packages using ssh\n"
  printf "\t--upload-host: use the following upload host\n"
  printf "\t--no-inc: do not increase version for rolling release\n"
  printf "\t--no-delete: do not delete old files during rsync\n"
  printf "\t--dist: touch the specified dist only\n"
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
      BUILD_STAGE=1
      SIGN_STAGE=1
      UPLOAD_STAGE=1
      ;;
    --build)
      BUILD_STAGE=1
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
    --upload-host)
      UPLOAD_HOST="${VALUE}"
      ;;
    --dist)
      DIST=1
      DISTS="${VALUE}"
      ;;
    *)
      echo "ERROR: unknown parameter \"$PARAM\""
      usage
      exit 1
      ;;
  esac
  shift
done

. ./config.sh

rm ${LOG} || true

get_rspamd() {
  HOST=$1
  $SSH_CMD $HOST rm -fr rspamd rspamd.build
  $SSH_CMD $HOST git clone --recursive https://github.com/vstakhov/rspamd rspamd

  if [ -n "${STABLE}" ] ; then
    $SSH_CMD $HOST -c "( cd rspamd && git checkout ${RSPAMD_VER} )"

    if [ $? -ne 0 ] ; then
      exit 1
    fi
    
    if [ -d ./patches-stable/ ] ; then
      shopt -s nullglob
      for p in ./patches-stable/* ; do
        echo "Applying patch $p"
        cat $p | $SSH_CMD $HOST "( cd rspamd && patch -p1 )"
        if [ $? -ne 0 ] ; then
          exit 1
        fi
      done
    fi
  fi
}


get_rspamd $SSH_HOST_X86
get_rspamd $SSH_HOST_AARCH64
gh_hash=`$SSH_CMD $SSH_HOST_X86 "cd rspamd ; git rev-parse --short HEAD"`

build_rspamd_deb() {
  HOST=$1
  DIST=$2
  DISTVER=$3
  RSPAMD_REL=$4
  echo "Building rspamd-${RSPAMD_VER}-${RSPAMD_REL} for ${DIST}-${DISTVER}"
  $SSH_CMD $HOST "(cd ./rspamd && env CHANGELOG_NAME=\"Vsevolod Stakhov\" CHANGELOG_EMAIL=vsevolod@highsecure.ru ASAN=0 LUAJIT=1 DOCKER_REPO=\"rspamd/pkg\" PRESERVE_ENVVARS=\"LUAJIT,ASAN\" \
    VERSION=${RSPAMD_VER} RELEASE=${RSPAMD_REL} OS=${DIST} DIST=${DISTVER} ../packpack/packpack)" || { echo "Failed to build: rspamd-${RSPAMD_VER}-${RSPAMD_REL} for ${DIST}-${DISTVER}" ; exit 1 ; }
}

build_rspamd_rpm() {
  HOST=$1
  DIST=$2
  DISTVER=$3
  RSPAMD_REL=$4
  $SSH_CMD $HOST "(cd ./rspamd && env CHANGELOG_NAME=\"Vsevolod Stakhov\" CHANGELOG_EMAIL=vsevolod@highsecure.ru ASAN=0 LUAJIT=1 DOCKER_REPO=\"rspamd/pkg\" PRESERVE_ENVVARS=\"LUAJIT,ASAN\" \
    VERSION=${RSPAMD_VER} RELEASE=${RSPAMD_REL} OS=${DIST} DIST=${DISTVER} ../packpack/packpack)" || { echo "Failed to build: rspamd-${RSPAMD_VER}-${RSPAMD_REL} for ${DIST}-${DISTVER}" ; exit 1 ; } 
  $SSH_CMD $HOST "(cd ./rspamd && env CHANGELOG_NAME=\"Vsevolod Stakhov\" CHANGELOG_EMAIL=vsevolod@highsecure.ru ASAN=1 LUAJIT=1 DOCKER_REPO=\"rspamd/pkg\" PRESERVE_ENVVARS=\"LUAJIT,ASAN\" \
    VERSION=${RSPAMD_VER} RELEASE=${RSPAMD_REL} OS=${DIST} DIST=${DISTVER} ../packpack/packpack)" || { echo "Failed to build: rspamd-${RSPAMD_VER}-${RSPAMD_REL} for ${DIST}-${DISTVER}" ; exit 1 ; }
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
  if [ -n "${STABLE}" ] ; then
    _version="${STABLE_VER}"
  else
    _version=`cat ${HOME}/version || echo 0`
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
    build_rspamd_deb $SSH_HOST_X86 $_distro $_ver $pkg_version
    build_rspamd_deb $SSH_HOST_AARCH64 $_distro $_ver $pkg_version

  done
  for d in $DISTRIBS_RPM ; do    
    _distro=`echo $d | cut -d'-' -f 1`
    _ver=`echo $d | cut -d'-' -f 2`
    if [ -n "${STABLE}" ] ; then
      pkg_version="${_version}.git${gh_hash}"
    else
      pkg_version="0~git${_version}~${gh_hash}~$_ver"
    fi
    build_rspamd_rpm $SSH_HOST_X86 $_distro $_ver $pkg_version
    build_rspamd_rpm $SSH_HOST_AARCH64 $_distro $_ver $pkg_version
  done


  # Increase version
  if [ -z "${STABLE}" -a -z "${NO_INC}" ] ; then
    echo $_version > ${HOME}/version
  fi
fi

if [ ${SIGN_STAGE} -eq 1 ] ; then

  if [ -n "${STABLE}" ] ; then
    _version="${STABLE_VER}"
  else
    _version=`cat ${HOME}/version || echo 0`
  fi

  _id=`git -C ${HOME}/rspamd rev-parse --short HEAD`

  if [ $DEBIAN -ne 0 ] ; then
    rm -fr ${HOME}/repos/*
    gpg --armor --output ${HOME}/repos/gpg.key --export $KEY
    mkdir ${HOME}/repos/conf || true
    rm -fr ${HOME}/repos-asan/*
    gpg --armor --output ${HOME}/repos-asan/gpg.key --export $KEY
    mkdir ${HOME}/repos-asan/conf || true

    for d in $DISTRIBS_DEB ; do
      _distname=`echo $d | sed -r -e 's/ubuntu-|debian-//'`
      if [ -n "${STABLE}" ] ; then
        _pkg_ver="${RSPAMD_VER}-${_version}~${_distname}"
        _repo_descr="Apt repository for rspamd stable builds"
      else
        _pkg_ver="${RSPAMD_VER}-0~git${_version}~${_id}~${_distname}"
        _repo_descr="Apt repository for rspamd nightly builds"
      fi
      if [ -z "${NO_I386}" ] ; then
        ARCHS="source amd64 i386"
      else
        ARCHS="source amd64"
      fi
      if [ $ARM -ne 0 ] ; then
        ARCHS="${ARCHS} armhf"
      fi
      _repodir=${HOME}/repos/
      cat >> $_repodir/conf/distributions <<EOD
Origin: Rspamd
Label: Rspamd
Codename: ${_distname}
Architectures: ${ARCHS}
Components: main
Description: ${_repo_descr}
SignWith: ${KEY}

EOD
      dpkg-sig -k $KEY --batch=1 --sign builder ${HOME}/$d/release/rspamd_${_pkg_ver}*.deb
      dpkg-sig -k $KEY --batch=1 --sign builder ${HOME}/$d/release/rspamd-dbg_${_pkg_ver}*.deb
      debsign --re-sign -k $KEY ${HOME}/$d/release/rspamd_${_pkg_ver}*.changes
      reprepro -b $_repodir -v --keepunreferencedfiles includedeb $_distname $d/release/rspamd_${_pkg_ver}_amd64.deb
      reprepro -b $_repodir -v --keepunreferencedfiles includedeb $_distname $d/release/rspamd-dbg_${_pkg_ver}_amd64.deb
      reprepro -b $_repodir -v --keepunreferencedfiles includedsc $_distname $d/release/rspamd_${_pkg_ver}.dsc

      gpg -u 0x$KEY -sb $_repodir/dists/$_distname/Release && \
        mv $_repodir/dists/$_distname/Release.sig $_repodir/dists/$_distname/Release.gpg

      if [ ${NO_ASAN} -ne 1 ] ; then
        _repodir=${HOME}/repos-asan/
        cat >> $_repodir/conf/distributions <<EOD
Origin: Rspamd
Label: Rspamd
Codename: ${_distname}
Architectures: ${ARCHS}
Components: main
Description: ${_repo_descr} ASAN builds
SignWith: ${KEY}

EOD
        dpkg-sig -k $KEY --batch=1 --sign builder ${HOME}/$d/asan/rspamd_${_pkg_ver}*.deb
        dpkg-sig -k $KEY --batch=1 --sign builder ${HOME}/$d/asan/rspamd-dbg_${_pkg_ver}*.deb
        debsign --re-sign -k $KEY ${HOME}/$d/asan/rspamd_${_pkg_ver}*.changes
        reprepro -b $_repodir -V --keepunreferencedfiles includedeb $_distname $d/asan/rspamd_${_pkg_ver}_amd64.deb
        reprepro -b $_repodir -V --keepunreferencedfiles includedeb $_distname $d/asan/rspamd-dbg_${_pkg_ver}_amd64.deb
        reprepro -b $_repodir -V --keepunreferencedfiles includedsc $_distname $d/asan/rspamd_${_pkg_ver}.dsc

        gpg -u 0x$KEY -sb $_repodir/dists/$_distname/Release && \
          mv $_repodir/dists/$_distname/Release.sig $_repodir/dists/$_distname/Release.gpg
      fi # No asan
    done
  fi # DEBIAN == 0

  if [ $RPM -ne 0 ] ; then
    rm -f ${HOME}/rpm/gpg.key || true
    rm -f ${HOME}/rpm-asan/gpg.key || true
    ARCH="${MAIN_ARCH}"
    mkdir -p ${HOME}/rpm/ || true
    mkdir -p ${HOME}/rpm-asan/ || true
    gpg --armor --output ${HOME}/rpm/gpg.key --export $KEY
    gpg --armor --output ${HOME}/rpm-asan/gpg.key --export $KEY
    for d in $DISTRIBS_RPM_FULL ; do
      rm -fr ${HOME}/rpm/$d/ || true
      rm -fr ${HOME}/rpm-asan/$d/ || true
      mkdir -p ${HOME}/rpm/$d/${ARCH} || true
      mkdir -p ${HOME}/rpm-asan/$d/${ARCH} || true
    done
    for d in $DISTRIBS_RPM ; do
      cp ${HOME}/${d}/${BUILD_DIR}/RPMS/${ARCH}/*.rpm ${HOME}/rpm/$d/${ARCH}
      for p in ${HOME}/rpm/$d/${ARCH}/*.rpm ; do
        ./rpm_sign.expect $p
      done
      (cd ${HOME}/rpm/$d/${ARCH} && createrepo --compress-type gz . )

      gpg --default-key ${KEY} --detach-sign --armor \
        ${HOME}/rpm/$d/${ARCH}/repodata/repomd.xml

      if [ ${NO_ASAN} -ne 1 ] ; then
        cp ${HOME}/${d}/${BUILD_DIR}-asan/RPMS/${ARCH}/*.rpm ${HOME}/rpm-asan/$d/${ARCH}
        for p in ${HOME}/rpm-asan/$d/${ARCH}/*.rpm ; do
          ./rpm_sign.expect $p
        done
        (cd ${HOME}/rpm-asan/$d/${ARCH} && createrepo --compress-type gz . )

        gpg --default-key ${KEY} --detach-sign --armor \
          ${HOME}/rpm-asan/$d/${ARCH}/repodata/repomd.xml
      fi

      if [ -n "${STABLE}" ] ; then
        cat <<EOD > ${HOME}/rpm/$d/rspamd.repo
[rspamd]
name=Rspamd stable repository
baseurl=http://rspamd.com/rpm-stable/$d/${ARCH}/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=http://rspamd.com/rpm/gpg.key
EOD
        cat <<EOD > ${HOME}/rpm-asan/$d/rspamd.repo
[rspamd]
name=Rspamd stable repository (asan enabled)
baseurl=http://rspamd.com/rpm-stable-asan/$d/${ARCH}/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=http://rspamd.com/rpm/gpg.key
EOD
      else
        cat <<EOD > ${HOME}/rpm/$d/rspamd-experimental.repo
[rspamd-experimental]
name=Rspamd experimental repository
baseurl=http://rspamd.com/rpm/$d/${ARCH}/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=http://rspamd.com/rpm/gpg.key
EOD
        cat <<EOD > ${HOME}/rpm-asan/$d/rspamd-experimental.repo
[rspamd-experimental]
name=Rspamd experimental repository (asan enabled)
baseurl=http://rspamd.com/rpm-asan/$d/${ARCH}/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=http://rspamd.com/rpm/gpg.key
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
        ${HOME}/repos/* ${UPLOAD_HOST}:${UPLOAD_SUFFIX}${TARGET_DEB_STABLE}
      if [ ${NO_ASAN} -ne 1 ] ; then
        rsync -e "ssh -i ${SSH_KEY_DEB_STABLE}" ${RSYNC_ARGS} \
          ${HOME}/repos-asan/* ${UPLOAD_HOST}:${UPLOAD_SUFFIX}${TARGET_DEB_STABLE}-asan
      fi
    else
      rsync -e "ssh -i ${SSH_KEY_DEB_UNSTABLE}" ${RSYNC_ARGS} \
        ${HOME}/repos/* ${UPLOAD_HOST}:${UPLOAD_SUFFIX}${TARGET_DEB_UNSTABLE}
      if [ ${NO_ASAN} -ne 1 ] ; then
        rsync -e "ssh -i ${SSH_KEY_DEB_UNSTABLE}" ${RSYNC_ARGS} \
          ${HOME}/repos-asan/* ${UPLOAD_HOST}:${UPLOAD_SUFFIX}${TARGET_DEB_UNSTABLE}-asan
      fi
    fi
  fi

  if [ $RPM -ne 0 ] ; then
    for d in $DISTRIBS_RPM ; do
      if [ -n "${STABLE}" ] ; then
        rsync -e "ssh -i ${SSH_KEY_RPM_STABLE}" ${RSYNC_ARGS} \
          ${HOME}/rpm/$d/* ${UPLOAD_HOST}:${UPLOAD_SUFFIX}${TARGET_RPM_STABLE}/$d/
        if [ ${NO_ASAN} -ne 1 ] ; then
          rsync -e "ssh -i ${SSH_KEY_RPM_STABLE}" ${RSYNC_ARGS} \
            ${HOME}/rpm-asan/$d/* ${UPLOAD_HOST}:${UPLOAD_SUFFIX}${TARGET_RPM_STABLE}-asan/$d/
        fi
      else
        rsync -e "ssh -i ${SSH_KEY_RPM_UNSTABLE}" ${RSYNC_ARGS} \
          ${HOME}/rpm/$d/* ${UPLOAD_HOST}:${UPLOAD_SUFFIX}${TARGET_RPM_UNSTABLE}/$d/
        if [ ${NO_ASAN} -ne 1 ] ; then
          rsync -e "ssh -i ${SSH_KEY_RPM_UNSTABLE}" ${RSYNC_ARGS} \
            ${HOME}/rpm-asan/$d/* ${UPLOAD_HOST}:${UPLOAD_SUFFIX}${TARGET_RPM_UNSTABLE}-asan/$d/
        fi
      fi
    done
  fi
fi
