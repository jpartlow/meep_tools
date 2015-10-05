set -e
#set -x

. ./common.sh

target=${1}

if [ -z "${target}" ]; then
    echo "Usage: inject-classifier-tool.sh <puppet-master-hostname>"
    echo "Example: inject-classifier-tool.sh pe-201530-master.puppetdebug.vlan"
    exit 1
fi

ensure_rsync $PLATFORM $target

ruby_bin='/opt/puppetlabs/puppet/bin'
ssh_on $target "${ruby_bin?}/gem install puppetclassify"
rsync_on $target ./classification-tool.rb /usr/local/bin
