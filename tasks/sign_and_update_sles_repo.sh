#! /usr/bin/env bash

set -e

# The absolute path to the yum repository
# shellcheck disable=SC2154
pe_package_dir=$PT_repo_dir

zypper install -y createrepo

# ensure pub key is imported into rpm
rpm --import /root/GPG-KEY-frankenbuilder.pub

# rebuild repo
pushd "${pe_package_dir}"
  createrepo --update .
popd

# sign repomd
rm -f "${pe_package_dir}/repodata/repomd.xml.asc"
gpg --detach-sign --armor --force-v3-sigs "${pe_package_dir}/repodata/repomd.xml"
