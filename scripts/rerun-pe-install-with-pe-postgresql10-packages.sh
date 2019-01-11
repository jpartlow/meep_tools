#! /bin/bash

# When executed on a master platform vm, assuming scripts/nfs-mount.sh has been
# used to set up nfs mount to my src dir, and a 2019.1 PE tarball has been
# extracted in /root, this script automates copying in newly built
# pe-postgresql<ver>* packages into the PE tarball, signing them or the repodata
# (depends on platform) with the frankenbuild gpg key and updating the
# repository so that they can be installed.
#
# It completely uninstalls PE, then preps an install and links in my current
# puppetlabs-puppet_enterprise module from source before installing completely.

#set -x
set -e

postgres_major_version=$1

if [ "${postgres_major_version}" != "9.6" ] &&
   [ "${postgres_major_version}" != "10" ] &&
   [ "${postgres_major_version}" != "11" ]; then
  echo "Usage: re-run-pe-install-wtih-pe-postgresql-packages.sh <postgres_version>"
  echo "  where <postgres_version> should be the major version without punctuation"
  echo "  (so 9.6, 10 or 11...)"
  exit 1
fi

platform=$(/opt/puppetlabs/bin/puppet facts | grep platform_tag | grep -oE '[a-z0-9_]+-[a-z0-9_.]+-[a-z0-9_]+')
os=${platform%%-*}
_os_name_and_ver=${platform%-*}
os_ver=${_os_name_and_ver#*-}
os_arch=${platform##*-}
if [ "$os" == 'ubuntu' ]; then
  if [ "$os_ver" == '18.04' ]; then
    codename=bionic
  else
    codename=xenial
  fi
fi
pe_dir="/root/$(ls -d puppet-enterprise-2019.1.0*"${os_arch}")"
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

    yum install -y tree vim rpm-sign createrepo expect

    # cp my dev postgres packages into the pe tarball
    cp /jpartlow-src/puppet-enterprise-vanagon/output/"$os"/"$os_ver"/products/x86_64/*.rpm "${pe_package_dir}"

    # ensure pub key is imported into rpm
    rpm --import gpg/GPG-KEY-frankenbuilder.pub

    # sign packages (sign any built versioned packages, since we might want to
    # install side by side)
    for package in ${pe_package_dir}/pe-postgresql{96,10,11}*; do
      if [ -f "$package" ]; then
        echo "$package"

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
      fi
    done

    # rebuild repo
    pushd "${pe_package_dir}"
      createrepo --update .
    popd
    ;;
  sles)
    zypper install -y tree vim createrepo

    # cp my dev postgres packages into the pe tarball
    cp /jpartlow-src/puppet-enterprise-vanagon/output/"$os"/"$os_ver"/products/x86_64/*.rpm "${pe_package_dir}"

    # ensure pub key is imported into rpm
    rpm --import gpg/GPG-KEY-frankenbuilder.pub

    # rebuild repo
    pushd "${pe_package_dir}"
      createrepo --update .
    popd

    # sign repomd
    rm -f "${pe_package_dir}/repodata/repomd.xml.asc"
    gpg --detach-sign --armor --force-v3-sigs "${pe_package_dir}/repodata/repomd.xml"
    ;;
  ubuntu)
    apt install -y tree vim dpkg-dev

    cp /jpartlow-src/puppet-enterprise-vanagon/output/deb/"$codename"/*.deb "${pe_package_dir}"

    # shellcheck disable=SC2002
    cat /root/gpg/GPG-KEY-frankenbuilder.pub | apt-key add -

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
Architecture: ${os_arch}
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
    ;;
  *)
    echo "Unknown platform: ${platform}"
    exit 2
    ;;
esac

if grep -E '^[^#]*postgres_version_override' "${pe_dir}/conf.d/custom-pe.conf"; then
  sed -e "/postgres_version_override/ s/\"[0-9]\+\"/\"${postgres_major_version}\"/" -i "${pe_dir}/conf.d/custom-pe.conf"
else
  sed -e "/\"console_admin_password\"/ a \"puppet_enterprise::postgres_version_override\": \"${postgres_major_version}\"" -i "${pe_dir}/conf.d/custom-pe.conf"
fi

# retry pe installation
/jpartlow-src/integration-tools/scripts/rerun-pe-install-with-module-links.sh -d "${pe_dir}" -m puppet_enterprise,pe_postgresql
