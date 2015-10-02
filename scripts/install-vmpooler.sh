set -e
#set -x

. ./common.sh

if [ -z "$1" -o -z "$2" -o -z "$3" ]; then
    echo "Usage: install-vmpooler.sh <pooler-hostname> <full-pe-version> <platform-string>"
    echo "Example: ./install-vmpooler.sh yjhugvpv1mzq5xl 2015.3.0-rc3-189-gd189eda el-7-x86_64"
    echo
    exit 1
fi

host="${1?}.delivery.puppetlabs.net"
version="${2?}"
platform="${3?}"

ensure_rsync $platform $host
rsync --progress -a pe_builds/puppet-enterprise-${version?}-${platform?} root@${host?}:
rsync --progress answers.master root@${host?}:
ssh root@${host?} "sed -i -e 's/pe-[0-9]*-master.puppetdebug.vlan/${host?}/' answers.master"
echo "log on and run installer"
