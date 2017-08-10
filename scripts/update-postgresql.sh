#! /bin/bash

set -e

while getopts d opt; do
  case "$opt" in
    d)
       set -x
       shift
       ;;
  esac
done

target_dir=$(readlink -f "$1")

BASE_BUILDS_POSTGRES_URL='http://builds.puppetlabs.lan/puppet-enterprise-vanagon'
CURRENT_POSTGRES_COMMIT='b7c06337a064ca8c8c7013825be49821f41146af'
CURRENT_POSTGRES_VERSION='2017.3.9.6.3-0.1'
#http://builds.puppetlabs.lan/puppet-enterprise-vanagon/b7c06337a064ca8c8c7013825be49821f41146af/artifacts/el/7/products/x86_64/pe-postgresql-2017.3.9.6.3-0.1.pe.el7.x86_64.rpm
CURRENT_PGLOGICAL_COMMIT='72e348435cd5f4b61f9001ec1918a4a2932ac181'
CURRENT_PGLOGICAL_VERSION='2017.3.1.2.1-2'
#http://builds.puppetlabs.lan/puppet-enterprise-vanagon/72e348435cd5f4b61f9001ec1918a4a2932ac181/artifacts/el/7/products/x86_64/pe-postgresql-pglogical-2017.3.1.2.1-2.pe.el7.x86_64.rpm

if [ ! -d "${target_dir?}" ]; then
  cat <<-EOS
  Updates an el frankenbuilder/frankenbuild tarball directory with newer
  postgresql 9.6 packages from ${BASE_BUILDS_POSTGRES_URL}/${CURRENT_POSTGRES_COMMIT}.

  Usage: update-postgresql [-d] <path-to-frankenbuilder/frankenbuild>

  -d : Sets debug tracing
EOS
  exit 1
fi

# shellcheck source=/dev/null
source "${target_dir?}/packages/bootstrap-metadata"

postgres_packages=(pe-postgresql pe-postgresql-contrib pe-postgresql-devel pe-postgresql-server)
platform=${PLATFORM_TAG%%-*}
rest=${PLATFORM_TAG#*-}
version=${rest%%-*}
arch=${PLATFORM_TAG##*-}

builds_url="${BASE_BUILDS_POSTGRES_URL?}/${CURRENT_POSTGRES_COMMIT?}/artifacts/${platform?}/${version?}/products/${arch?}/"

pushd "${target_dir?}"
  pushd "packages/${PLATFORM_TAG?}"
    for package in "${postgres_packages[@]}"; do
      wget -N "${builds_url?}/${package?}-${CURRENT_POSTGRES_VERSION?}.pe.${platform?}${version?}.${arch?}.rpm"
    done

    # pglogical
    builds_url="${BASE_BUILDS_POSTGRES_URL?}/${CURRENT_PGLOGICAL_COMMIT?}/artifacts/${platform?}/${version?}/products/${arch?}/"
    wget -N "${builds_url?}/pe-postgresql-pglogical-${CURRENT_PGLOGICAL_VERSION?}.pe.${platform?}${version?}.${arch?}.rpm"
  popd
  
  createrepo --update "packages/${PLATFORM_TAG?}"

  sed -i "s/2017.3.9.4.*\",/${CURRENT_POSTGRES_VERSION%-*}\",/" "packages/${PLATFORM_TAG}-package-versions.json"

  sed -i "s/gpgcheck=1/gpgcheck=0/" puppet-enterprise-installer

  release="puppet-enterprise-${PE_BUILD_VERSION}-${PLATFORM_TAG}"
  tarball="${release?}.tar.gz"
  rm -f "$tarball"
  tmpdir=$(mktemp -d)
  tmprelease_path="${tmpdir?}/${release?}"
  ln -s "${target_dir?}" "${tmprelease_path?}" 
  set +e
  tar --warning=no-file-changed -chzf "$tarball" -C "${tmpdir?}" "${release?}"
  set -e
popd

exit 0
