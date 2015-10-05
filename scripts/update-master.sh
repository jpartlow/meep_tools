#! /bin/bash
set -e
set -x

master=$1
SRC_DIR=/home/jpartlow/work/src/pl/pe-modules

if [ $# -lt 2 ]; then
    echo "USAGE: update_master.sh <hostname> <list> <of> <modules>"
    echo "Need to supply the vmpooler or vagrant master hostname to update and a list of modules to update on it"
    echo "Example: update_master.sh pe-201520-master.puppetdebug.vlan puppet_agent pe_repo"
    exit 1
fi
shift

. ./common.sh

ensure_rsync $PLATFORM $master

ssh_on $master 'echo done'

for module in "$@"; do
    if [[ ! "$module" =~ ^puppetlabs ]]; then
        module="puppetlabs-${module}"
    fi
    echo "Packaging ${module}"
    srcdir=$SRC_DIR
    pushd $srcdir/$module > /dev/null
    bundle exec rake clean
    bundle exec rake build
    package_name=$(basename pkg/$module-*.tar.gz)
    popd > /dev/null
    echo "Rsyncing ${module}"
    rsync_on $master $srcdir/$module/pkg/$package_name

    if [ "$module" == "puppetlabs-puppet_agent" ]; then
        echo "install puppet_agent in codedir"
        modulepath=$(ssh root@$master 'puppet config print modulepath')
        puppet_agent_dir=$(ssh root@$master "ls ${modulepath%%:*}")
        regex="puppet_agent"
        if [[ "${puppet_agent_dir?}" =~ ${regex?} ]]; then
          options="--force"
        fi
        ssh_on $master "/opt/puppetlabs/bin/puppet module install $options /root/$package_name --environment production"
    else
        echo "install $module in basemodulepath"
        ssh_on $master "/opt/puppetlabs/bin/puppet module install --force /root/$package_name --modulepath /opt/puppetlabs/puppet/modules"
    fi 
done
