#! /usr/bin/env bash

set -e

# The directory we are allowing NFS to mount.
# shellcheck disable=SC2154
source_dir=$PT_source_dir
# The target node that should be allowed to mount the source_dir.
# shellcheck disable=SC2154
target_ip=$PT_target_ip
# The anonuid to set
# shellcheck disable=SC2154
anonuid=$PT_user_id
# The anongid to set
# shellcheck disable=SC2154
anongid=$PT_group_id

export_line="\"${source_dir:?}\" ${target_ip:?}(ro,no_subtree_check,all_squash,anonuid=${anonuid:?},anongid=${anongid:?})"

if ! grep -q "${export_line}" /etc/exports; then
  echo "${export_line} # $(date)" >> /etc/exports
  sudo exportfs -a
  echo "{\"exported\": \"${export_line}\"}"
fi
