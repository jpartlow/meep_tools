set -e

. common.sh

SRC_DIR=~/work/src/pl
pushd pe_builds > /dev/null
BUILD=$(find -type d -name "puppet-enterprise-${FULL_VER?}-*-${PLATFORM_STRING?}*" -printf "%f\n" | sort | tail -n1)
echo "BUILD: $BUILD"
popd > /dev/null
REV=${BUILD%%-${PLATFORM_STRING?}*}
REV=${REV##puppet-enterprise*-g}
echo "$BUILD"
echo "$REV"

# reset files
cd pe_builds
rm -rf "$BUILD"
tar -xzf "${BUILD}.tar.gz"
cd "$BUILD"
WORKSPACE=$(pwd)

echo " * Pull in new modules"
for module_name in 'puppetlabs-puppet_enterprise' 'puppetlabs-pe_repo'; do
  echo " ** Checking ${module_name?}"
  t_module_file=$(find "$WORKSPACE/modules" -name "${module_name?}*" | sort | tail -n1)
  t_module_file_name=$(basename "${t_module_file?}")
  MOD_REV=${t_module_file%%.tar.gz}
  MOD_REV=${MOD_REV##*${module_name?}*-g}
  pushd "$SRC_DIR/${module_name?}" > /dev/null
  LOCAL_MOD_REV=$(git rev-parse HEAD)
  if git merge-base --is-ancestor "$MOD_REV" "$LOCAL_MOD_REV" && [ "$(git rev-parse "$MOD_REV")" != "$LOCAL_MOD_REV" ]; then
    t_newer_local_mod=1
  else
    t_newer_local_mod=0
  fi
  popd > /dev/null

  if [ "$t_newer_local_mod" == '1' ] ; then
    echo "Newer ${module_name?} module found: ${LOCAL_MOD_REV} is not an ancestor of current module rev: ${MOD_REV}"
    pushd modules > /dev/null
    mv "${t_module_file_name?}" "original-${t_module_file_name?}"
    pushd "$SRC_DIR/${module_name?}" > /dev/null
    bundle exec rake clean
    bundle exec rake build
    popd > /dev/null
    cp ${SRC_DIR}/${module_name?}/pkg/${module_name?}-*.tar.gz .
    popd > /dev/null
    echo "Copied in module built from local repo: ${SRC_DIR}/${module_name?}"
  else
    echo "Module up to date"
  fi
done
echo

echo " * Apply installer patch"
pushd $SRC_DIR/enterprise-dist > /dev/null
git diff "${REV}" -- installer > "$WORKSPACE/installer.patch"
popd > /dev/null
patch < installer.patch
echo

echo " * Apply erb templates patch"
pushd $SRC_DIR/enterprise-dist > /dev/null
git diff "${REV}" -- ext/erb > "$WORKSPACE/erb.patch"
popd > /dev/null
patch -p2 < erb.patch
echo

echo "DONE"
