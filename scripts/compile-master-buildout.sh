#! /bin/bash

#set -e
#set -x

MEEP_CLASSIFICATION=true
while getopts p:m name; do
  case "$name" in
    m)
        MEEP_CLASSIFICATION=false
        shift
        ;;
    p)
        path="${OPTARG?}"
        shift
        shift
        ;;
  esac
done

. ./common.sh
compressed_version="${compressed_version:-$(echo "$FULL_VER" | sed -re 's/\.//g')}"
default_domain='puppetdebug.vlan'
mom=${1:-"pe-${compressed_version}-master.${default_domain}"}
cm=${2:-pe-${compressed_version}-compile.${default_domain}}
agent=${3:-pe-${compressed_version}-agent.${default_domain}}
replica=${4:-pe-${compressed_version}-replica.${default_domain}}

if (( ${VER%%.*} < 4 )); then
    ruby_bin='/opt/puppet/bin'
else
    ruby_bin='/opt/puppetlabs/puppet/bin'
fi

set +e
ssh_on "$mom" 'true'
found_mom=$?
ssh_on "$cm" 'true'
found_cm=$?
ssh_on "$agent" 'true'
found_agent=$?
ssh_on "$replica" 'true'
found_replica=$?
set -e

if [ "$found_mom" != '0' -o "$found_cm" != '0' -o "$found_agent" != '0' ]; then
    echo "Usage: compile-master-buildout.sh [-m] <mono-mom-hostname> <cm-hostname> <agent-hostname> [replica-hostname]"
    echo "  options:"
    echo "  -m : without meep classification (manipulate legacy node groups)"
    echo ""
    echo "Example: compile-master-buildout.sh pe-201530-master pe-201530-cm pe-201530-agent"
    echo "If no domain is provided puppetdebug.vlan is assumed"
    echo "Will do a monolithic install on the master node"
    echo "** This script currently only works in my local vms!"
    echo "** Would make more sense to run this with Beaker..."
fi

if [ -z "$BUILD" ] && [ -z "$path" ]; then
    echo "!! Failed to find a build"
fi

echo "* Installing $BUILD onto $mom"

function install_agent() {
  local node=$1
  local master=$2
  local frictionless_args=$3

  ssh_on "$node" "sudo /vagrant/frictionless.sh ${master} ${frictionless_args}"
  ssh_on "$node" "sudo /usr/local/bin/puppet agent -t"
  ssh_on "$master" "sudo /usr/local/bin/puppet cert sign $node"
  ssh_on "$node" "sudo /usr/local/bin/puppet agent -t"
}

set +e
if [ -n "$path" ]; then
    path_to_build="$path"
else
    path_to_build="/pe_builds/$BUILD"
fi

ssh_on "$mom" "sudo /vagrant/do-pem-install.sh -p ${path_to_build?}"
./inject-classification-tool.sh "$mom"
install_agent "$cm" "$mom"
if ! $MEEP_CLASSIFICATION; then
  ssh_on "$mom" "sudo ${ruby_bin}/ruby /usr/local/bin/classification-tool.rb compile install $cm"
  ssh_on "$cm"  'sudo /usr/local/bin/puppet agent -t' # build cm
  ssh_on "$mom" 'sudo /usr/local/bin/puppet agent -t' # to set whitelists
fi

if $MEEP_CLASSIFICATION; then
  install_agent "$agent" "$mom"
else
  install_agent "$agent" "$mom" "main:server=${cm}"
fi

if [ $found_replica == '0' ]; then
  install_agent "$replica" "$mom"
fi
