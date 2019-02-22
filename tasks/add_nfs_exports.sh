#! /usr/bin/env bash

# shellcheck disable=SC2154
# The directory we are allowing NFS to mount.
source_dir=$PT_source_dir
# The target node that should be allowed to mount the source_dir.
target_ip=$PT_target_ip

export_line="\"${source_dir:?}\" ${target_ip:?}(ro,no_subtree_check,all_squash,anonuid=1000,anongid=1000)"

if ! grep -q "${export_line}" /etc/exports; then
  echo "${export_line} # $(date)" >> /etc/exports
  sudo exportfs -a
  echo "{\"exported\": \"${export_line}\"}"
fi
