#! /usr/bin/env bash

set -e

# The absolute path to the yum repository
# shellcheck disable=SC2154
pe_package_dir=$PT_repo_dir

# The Ubuntu os codename
# shellcheck disable=SC2154
codename=$PT_os_codename

apt install -y dpkg-dev

# shellcheck disable=SC2002
cat /root/GPG-KEY-frankenbuilder.pub | apt-key add -

rm "${pe_package_dir}"/{Release,Release.gpg,Packages,Packages.gz}

pushd "${pe_package_dir}"
  dpkg-scanpackages . /dev/null 1> "${pe_package_dir}/Packages"
  gzip -9c "${pe_package_dir}/Packages" > "${pe_package_dir}/Packages.gz"
popd

get_md5() {
  local output
  output=$(md5sum "${pe_package_dir}/$1" | cut --delimiter=' ' --fields=1)
  echo "$output"
}

get_sha() {
  local output
  output=$(sha256sum "${pe_package_dir}/$1" | cut --delimiter=' ' --fields=1)
  echo "$output"
}

get_bytes() {
  local output
  output=$(wc --bytes "${pe_package_dir}/$1" | cut --delimiter=' ' --fields=1)
  echo "$output"
}

# Generate Release file
release_file_contents="Origin: Puppetlabs
Label: Puppet Enterprise
Codename: ${codename}
Architecture: amd64
MD5Sum:
 $(get_md5 "Packages") $(get_bytes "Packages") Packages
 $(get_md5 "Packages.gz") $(get_bytes "Packages.gz") Packages.gz
SHA256:
 $(get_sha "Packages") $(get_bytes "Packages") Packages
 $(get_sha "Packages.gz") $(get_bytes "Packages.gz") Packages.gz
"

remote_release_file="${pe_package_dir}/Release"
remote_release_file_asc="${pe_package_dir}/Release.gpg"
echo "${release_file_contents}" > "$remote_release_file"
chmod 644 "${remote_release_file}"

gpg --armor --detach-sign --output "${remote_release_file_asc}" "${remote_release_file}"
