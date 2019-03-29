#! /usr/bin/env bash

set -e

# The absolute path to the yum repository
# shellcheck disable=SC2154
pe_package_dir="$PT_repo_dir"

# List of package names that need to be signed
# shellcheck disable=SC2154
packages=($PT_packages)

# The Redhat os major version
# shellcheck disable=SC2154
os_ver="$PT_os_major_version"

yum install -y rpm-sign createrepo expect

# ensure pub key is imported into rpm
rpm --import /root/GPG-KEY-frankenbuilder.pub

# sign packages (sign any built versioned packages, since we might want to
# install side by side)
for package_name in ${packages[*]}; do
  package="${pe_package_dir}/${package_name}"

  if [ "$os_ver" == "6" ]; then
    keyid=''
    cat > /root/.rpmmacros <<EOF
%_signature gpg
%_gpg_path /root/.gnupg
%_gpg_name Frankenbuilder Signing Key <team-organizational-scale@puppet.com>
%_gpgbin /usr/bin/gpg
EOF
    else
      keyid="--key-id frankenbuilder"
    fi

    # use expect to get the empty passphrase to gpg beneath rpmsign
    # (the need for this is beyond stupid)
    cat > /tmp/rpmsign.expect <<EOF
  set timeout -1

  spawn rpmsign ${keyid} --addsign $package

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
