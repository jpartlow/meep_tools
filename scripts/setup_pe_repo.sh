set -e
#set -x

. ./common.sh

target=${1}
puppet_agent_version=${2}

if [ -z "${target}" -o -z "${puppet_agent_version}" ]; then
    echo "Usage: setup_pe_repo.sh <puppet-master-hostname> <puppet-agent-version>"
    echo "Example: setup_pe_repo.sh pe-201530-master.puppetdebug.vlan 1.2.5"
    exit 1
fi

ensure_rsync $PLATFORM $target

ruby_bin='/opt/puppetlabs/puppet/bin'
ssh_on $target "${ruby_bin?}/gem install puppetclassify"
rsync_on $target ./pe_repo.rb /tmp
#ssh_on $target "${ruby_bin?}/ruby /tmp/pe_repo.rb"
