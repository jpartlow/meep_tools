#! /usr/bin/env bash

set -e

# shellcheck disable=SC2154
# The ip of the host providing the nfs directory
source_ip=$PT_source_ip
# The directory on the source host to mount from
source_dir=$PT_source_dir
# The local directory to mount at
local_mount_dir=$PT_local_mount_dir

if ! mount | grep -q "${local_mount_dir:?}"; then
  mkdir "${local_mount_dir:?}"
  mount "${source_ip:?}:${source_dir:?}" "${local_mount_dir:?}"
  echo "{\"mounted\":\"${source_ip:?}:${source_dir:?} at ${local_mount_dir:?}\"}"
fi
