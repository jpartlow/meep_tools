#! /usr/bin/env bash

set -e

# shellcheck disable=SC2154
platform_tag=$PT_platform_tag
# shellcheck disable=SC2154
pe_version=$PT_version
# shellcheck disable=SC2154
pe_family=$PT_family

if [ -z "$pe_version" ] && [ -z "$pe_family" ]; then
  echo "Must set either version or family" >&2
  exit 1
fi

if [ -n "$pe_version" ]; then
  pe_family=$(echo "$pe_version" | grep -oE '^[0-9]+\.[0-9]+')
fi

if [[ "$pe_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  base_url="http://enterprise.delivery.puppetlabs.net/archives/releases/${pe_version}"
else
  base_url="http://enterprise.delivery.puppetlabs.net/${pe_family}/ci-ready"
fi

if [ -z "$pe_version" ]; then
  pe_version=$(curl "${base_url}/LATEST")
fi

pe_dir="puppet-enterprise-${pe_version}-${platform_tag}"
pe_tarball="${pe_dir}.tar"
pe_tarball_url="${base_url}/${pe_tarball}"

[ ! -f "${pe_tarball}" ] && wget "${pe_tarball_url}"
[ ! -d "${pe_dir}" ] && tar -xf "${pe_tarball}"

echo "{
  \"pe_dir\":\"${pe_dir}\",
  \"pe_tarball\":\"${pe_tarball}\",
  \"pe_tarball_url\":\"${pe_tarball_url}\",
  \"pe_family\":\"${pe_family}\"
}"
