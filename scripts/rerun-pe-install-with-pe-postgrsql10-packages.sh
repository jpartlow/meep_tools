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

platform=$(puppet facts | grep platform_tag | grep -oE '[a-z0-9_]+-[a-z0-9_.]+-[a-z0-9_]')
os=${platform%%-*}
osver=${platform#*-"${platform%-*}"}
if [ "$os" == 'ubuntu' ]; then
  if [ "$osver" == '18.04' ]; then
    oslabel=bionic
  else
    oslabel=precise
  fi
fi
pe_dir="/root/$(ls -d puppet-enterprise-2019.1.0*x86_64)"
pe_package_dir="${pe_dir}/packages/${platform}"

cd /root || exit 1

# get gpg keys
cp -r /jpartlow-src/frankenbuilder/gpg /root
set +e
gpg --import gpg/GPG-KEY-frankenbuilder
# gpg --import returns 2 when key is already present
# shellcheck disable=SC2181
exited=$?
[ $exited == 0 ] || [ $exited == 2 ] || exit 1
set -e

case "$os" in
  el)
    yum install -y tree vim rpm-build rpm-sign createrepo expect

    # cp my dev postgres10 packages into the pe tarball
    cp "/jpartlow-src/puppet-enterprise-vanagon/output/el/$osver/products/x86_64/*.rpm" "${pe_package_dir}"

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
    ;;
  ubuntu)
    apt install -y tree vim

    cp /jpartlow-src/puppet-enterprise-vanagon/output/deb/$oslabel/products/x86_64/*.deb "${pe_package_dir}"

    cat gpg/GPG-KEY-Frankenbuilder.pub | apt-key add -


    ;;
  sles)
    exit 2
    ;;
  *)
    exit 3
    ;;
esac

grep -E '^[^#]*postgres_version_override' "${pe_dir}/conf.d/custom-pe.conf" || exit 2

# retry pe installation
/jpartlow-src/integration-tools/scripts/rerun-pe-install-with-module-links.sh -d "${pe_dir}" -m puppet_enterprise,pe_postgresql
