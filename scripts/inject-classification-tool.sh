set -e
#set -x

INSTALL_RSYNC='true'

while getopts s name; do
  case "$name" in
    s)
      INSTALL_RSYNC='false'
      ;;
  esac
  shift
done

. ./common.sh

target=${1}
tool=${2:-all}

if [ -z "${target}" ]; then
    echo "Usage: inject-classifier-tool.sh [-s] <puppet-master-hostname> [tool]"
    echo "  (the tool argument may be 'all', 'classification' or 'rbac')"
    echo "  -s to skip installing rsync"
    echo "Example: inject-classifier-tool.sh pe-201530-master.puppetdebug.vlan"
    exit 1
fi

if [ "$INSTALL_RSYNC" = "true" ]; then
  ensure_rsync $PLATFORM $target
fi

echo "VER: ${VER}"
if (( ${VER%%.*} < 4 )); then
    ruby_bin='/opt/puppet/bin'
else
    ruby_bin='/opt/puppetlabs/puppet/bin'
fi

if [ "$tool" = "all" -o "$tool" = "classification" ]; then
  ssh_on $target "${ruby_bin?}/gem install puppetclassify"
  rsync_on $target ./classification-tool.rb /usr/local/bin
fi
if [ "$tool" = "all" -o "$tool" = "rbac" ]; then
  rsync_on $target /s/scripts/create_local_user.rb /usr/local/bin
fi
