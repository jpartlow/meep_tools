# Generate a tarball from the current enterprise-dist checkout for the given platform.

set -e
#set -x

. common.sh
platform="${1:-${PLATFORM_STRING}}"
version="${2:-${FULL_VER}}"

echo "platform: ${platform}"
echo "version: ${version}"

src_dir=/s
latest_pe_build="./pe_builds/${BUILD}"
enterprise_dist="${src_dir?}/enterprise-dist"

rm -rf "${enterprise_dist?}/installer/packages"
mkdir "${enterprise_dist?}/installer/packages"
cp -r "${latest_pe_build?}"/packages/* "${enterprise_dist?}/installer/packages"
rm -rf "${enterprise_dist?}/installer/modules"
mkdir "${enterprise_dist?}/installer/modules"
cp -r "${latest_pe_build?}"/modules/* "${enterprise_dist?}/installer/modules"

modules_src="${src_dir?}/modules"

red() {
  echo -e "\e[31m${1?}\e[39m"
}

green() {
  echo -e "\e[32m${1?}\e[39m"
}

yellow() {
  echo -e "\e[33m${1?}\e[39m"
}

blue() {
  echo -e "\e[34m${1?}\e[39m"
}

pushd "${enterprise_dist}/installer"

  pushd modules
    for module in 'puppetlabs-puppet_enterprise' 'puppetlabs-pe_manager' 'puppetlabs-pe_install'; do
      blue " * Checking ${module?}"
      original_module=$(basename "${module?}"*)
      echo "original_module: $original_module"
      MOD_REV=${original_module%%.tar.gz}
      MOD_REV=${MOD_REV##*${module}*-g}
      echo "MOD_REV: $MOD_REV"
      pushd "${modules_src?}/${module?}"
        LOCAL_MOD_REV=$(git rev-parse HEAD)
        if ! git branch --contains "$MOD_REV" 2>/dev/null; then
          red "!! Can't find '$MOD_REV' in current branch!"
          git status
          exit 1
        fi
        if ! git diff --quiet HEAD; then
          red "!! Local changes not committed, won't be picked up!"
          git status
          exit 1
        fi
        if git merge-base --is-ancestor "$MOD_REV" "$LOCAL_MOD_REV" && [ "$(git rev-parse "$MOD_REV")" != "$LOCAL_MOD_REV" ]; then
          t_newer_local_mod=1
        else
          t_newer_local_mod=0
        fi
      popd
      if [ "$t_newer_local_mod" == '1' ]; then
        yellow "-> Newer ${module?} module found: ${LOCAL_MOD_REV} is not an ancestor of current module rev: ${MOD_REV}"
        bundle exec puppet module build "${modules_src?}/${module?}" | grep "Module built:" | grep -Eo "/.*/${module?}-.*$"
        module_path=$(bundle exec puppet module build "${modules_src?}/${module?}" | grep "Module built:" | grep -Eo "/.*/${module?}-.*$")
        mv "${original_module?}" "original-${original_module?}"
        cp "${module_path?}" .
        yellow " ** Copied in module built from local repo: ${modules_src}/${module?}"
      else
        green "Module up to date"
      fi
    done
  popd

  # clear out old builds
  rm -rf "${enterprise_dist?}/dists"/puppet-enterprise*
  bundle exec rake dist PLATFORM_TAGS="${platform?}" 2>/dev/null

  # This is very hacky, should probably update installer.json to point to the ref we want rake task to pull in -- oh, but that's likely to be local only...
  pushd ../dists
    dist="puppet-enterprise-$(git describe)-${platform?}"
    tar -xf "${dist?}.tar"

    shim_rev=($(grep sha ../installer.json | grep -oE '[^": ]+'))
    shim_rev=${shim_rev[1]}
    dists_dir=$(pwd)
    blue " * Apply pe-installer-shim patch"
    pushd "$src_dir/pe-installer-shim"
      local_shim_rev=$(git describe)
      git diff "${shim_rev}" > "${dists_dir?}/installer.patch"
    popd
    echo
    if [ -s installer.patch ]; then
      yellow " * updating installer script from rev ${local_shim_rev?}"
      cat installer.patch
      pushd "${dist?}/pe-manager"
        patch < "${dists_dir?}/installer.patch"
      popd
      echo
    else
      green "Installer script up to date"
    fi

    if [ "${BUILD?}" != "${dist?}" ]; then
      red "!! latest in pe_builds is: ${BUILD}, but rake task built ${dist}"
      red "!! you need to get_latest_build() in your vm dir and retry (or modules will be out of date)"
      exit 1
    fi

    # TODO - tarball does not get the installer shim!
  popd
popd
