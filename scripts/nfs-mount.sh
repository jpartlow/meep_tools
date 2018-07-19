#! /bin/bash

pooler_host=$1

if [ -z "$pooler_host" ]; then
  echo "usage: nfs-mount.sh <host-fqdn>"
  echo "  Opens up nfs access for the host-fqdn ip, and sets up an nfs mount"
  echo "  on host-fqdn allowing /home/jpartlow/work/src to mount as /jpartlow-src."
  exit 1
fi

# Hard coded for present, and currently just using the slice ip...
slice_ip=10.32.163.108
#platform9_ip=10.234.0.206

. /home/jpartlow/work/src/integration-tools/scripts/common.sh

ssh_get "${pooler_host:?}" "facter networking.ip" "pooler_ip"

echo "\"/home/jpartlow/work/src\" ${pooler_ip:?}(ro,no_subtree_check,all_squash,anonuid=1000,anongid=1000,fsid=3725123654) # $(date)" >> /etc/exports
sudo exportfs -a

ssh_on "${pooler_host:?}" "mkdir /jpartlow-src"
ssh_on "${pooler_host:?}" "mount ${slice_ip:?}:/home/jpartlow/work/src /jpartlow-src"
