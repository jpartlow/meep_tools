#! /usr/bin/env bash

# shellcheck disable=SC2154 
platform_tag=$PT_platform_tag
pe_version=$PT_version

pe_family=$(echo "$pe_version" | grep -oE '^[0-9]+\.[0-9]+')
ci_ready_url="http://enterprise.delivery.puppetlabs.net/${pe_family}/ci-ready"
pe_dir="puppet-enterprise-${pe_version}-${platform_tag}"
pe_tarball="${pe_dir}.tar"
pe_tarball_url="${ci_ready_url}/${pe_tarball}"

[ ! -f "${pe_tarball}" ] && wget "${pe_tarball_url}"
[ ! -d "${pe_dir}" ] && tar -xf "${pe_tarball}"

echo "{
  \"pe_dir\":\"${pe_dir}\",
  \"pe_tarball\":\"${pe_tarball}\",
  \"pe_tarball_url\":\"${pe_tarball_url}\",
  \"pe_family\":\"${pe_family}\"
}"
