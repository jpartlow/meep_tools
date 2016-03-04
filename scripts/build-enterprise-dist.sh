# Generate a tarball from the current enterprise-dist checkout for the given platform.

set -e
#set -x

. common.sh
platform="${1:-${PLATFORM_STRING}}"
version="${2:-${FULL_VER}}"

echo "platform: ${platform}"
echo "version: ${version}"

src_dir=~/work/src/pl
latest_pe_build="./pe_builds/${BUILD}"
enterprise_dist="${src_dir?}/enterprise-dist"

rm -rf "${enterprise_dist?}/installer/packages"
mkdir "${enterprise_dist?}/installer/packages"
cp -r "${latest_pe_build?}"/packages/* "${enterprise_dist?}/installer/packages"
rm -rf "${enterprise_dist?}/installer/modules"
mkdir "${enterprise_dist?}/installer/modules"
cp -r "${latest_pe_build?}"/modules/* "${enterprise_dist?}/installer/modules"

modules_src="${src_dir?}/modules"

pushd "${enterprise_dist}/installer"

  pushd modules
    for module in 'puppetlabs-pe_manager' 'puppetlabs-pe_install'; do
      bundle exec puppet module build "${modules_src?}/${module?}" | grep "Module built:" | grep -Eo "/.*/${module?}-.*$"
      module_path=$(bundle exec puppet module build "${modules_src?}/${module?}" | grep "Module built:" | grep -Eo "/.*/${module?}-.*$")
      original_module=$(basename "${module?}"*)
      mv "${original_module?}" "original-${original_module?}"
      cp "${module_path?}" .
    done
  popd
  
  bundle exec rake dist PLATFORM_TAGS="${platform?}"
  
  pushd ../dists
    dist="puppet-enterprise-$(git describe)-${platform?}"
    rm -rf "${dist?}"
    tar -xf "${dist?}.tar"
  popd
popd
