#! /bin/bash

# When executed on a centos-7 vm, assuming scripts/nfs-mount.sh has been used
# to set up nfs mount to my src dir, and a 2019.1 PE tarball has been extracted
# in /root, this script automates copying in newly built pe-postgresql10* rpm
# packages into the PE tarball, signing them with the frankenbuild gpg key and
# updating the repository so that they can be installed.
#
# It completely uninstalls PE, then preps an install and links in my current
# puppetlabs-puppet_enterprise module from source before installing completely.

set -x
set -e

yum install -y tree vim rpm-build rpm-sign createrepo expect

cd /root || exit 1

pe_dir="/root/$(ls -d puppet-enterprise-2019.1.0*x86_64)"
pe_package_dir="${pe_dir}/packages/el-7-x86_64"

# cp my dev postgres10 packages into the pe tarball
cp /jpartlow-src/puppet-enterprise-vanagon/output/el/7/products/x86_64/*.rpm "${pe_package_dir}"

# get gpg keys
cp -r /jpartlow-src/frankenbuilder/gpg /root
set +e
gpg --import gpg/GPG-KEY-frankenbuilder
# gpg --import returns 2 when key is already present
# shellcheck disable=SC2181
exited=$?
[ $exited == 0 ] || [ $exited == 2 ] || exit 1
set -e

# ensure pub key is imported into rpm
rpm --import gpg/GPG-KEY-frankenbuilder.pub

# sign packages
for package in ${pe_package_dir}/pe-postgresql10*; do
  echo "$package"

  # use expect to get the empty passphrase to gpg beneath rpmsign
  # (the need for this is beyond stupid)
  cat > /tmp/rpmsign.expect <<EOF
  set timeout -1
  
  spawn rpmsign --key-id frankenbuilder --addsign $package
  
  expect "Enter pass phrase: "
  
  send "\r"
  
  expect "phrase is good."
  expect "$package:"
  expect eof
EOF
  
  expect -d /tmp/rpmsign.expect
  rpm -K "$package" | grep pgp || exit 3
done

# rebuild repo
pushd "${pe_package_dir}"
  createrepo --update .
popd

grep -E '^[^#]*postgres_version_override' "${pe_dir}/conf.d/custom-pe.conf" || exit 2

# retry pe installation
/jpartlow-src/integration-tools/scripts/rerun-pe-install-with-module-links.sh -d "${pe_dir}" -m puppet_enterprise
