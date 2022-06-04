#!/bin/bash
set -eE

function getVersion {
  local buildTS;
  local buildYear;
  local version;
  buildTS="$(date '+%Y%m%d%H%M%S')"
  buildYear="$(date '+%Y')"

  if [ -z "${TRAVIS_BRANCH}" ]; then
    version="local-${buildTS}"
  else
    if [[ -n $TRAVIS_TAG ]]; then
      version="${TRAVIS_TAG}"
    else
      version="${TRAVIS_BRANCH}-${buildTS}"
    fi
  fi
  echo "${version}"
}

function main {
  local buildDir;
  local buildYear;
  local version;
  local archiveName;

  buildDir="$(dirname "$0")/build"
  buildYear="$(date '+%Y')"
  version="$(getVersion "${buildDir}")"
  archiveName="synogandip-${version}.zip"

  echo "building archive [${archiveName}] (${buildYear}) ..."

  echo "cleaning ${buildDir} ..."
  rm -rfv "${buildDir:?}"/*
  mkdir -p "${buildDir}/synogandip"

  echo "copying files ..."
  cp -v ./src/* "${buildDir}/synogandip"

  echo "setting version ..."
  sed -i.tmp \
      -e 's@__version__@'"${version}"'@g' \
      -e 's@__year__@'"${buildYear}"'@g' \
      "${buildDir}/synogandip/synogandip.sh"
  rm "${buildDir}"/synogandip/*.tmp

  echo "creating archive ..."
  cd "${buildDir}" && zip -r "${archiveName}" synogandip
  echo "archive created:"
  ls -l "${archiveName}"
  echo "$(pwd)/${archiveName}"

  echo "build completed."
}

main "$@"
