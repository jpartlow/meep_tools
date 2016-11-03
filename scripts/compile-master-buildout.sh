#set -e
#set -x

. common.sh
compressed_version="${compressed_version:-$(echo "$FULL_VER" | sed -re 's/\.//g')}"
default_domain='puppetdebug.vlan'
mom=${1:-"pe-${compressed_version}-master.${default_domain}"}
cm=${2:-pe-${compressed_version}-compile.${default_domain}}
agent=${3:-pe-${compressed_version}-agent.${default_domain}}
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
set -e

if [ "$found_mom" != '0' -o "$found_cm" != '0' -o "$found_agent" != '0' ]; then
    echo "Usage: compile-master-buildout.sh <mono-mom-hostname> <cm-hostname> <agent-hostname>"
    echo "Example: compile-master-buildout.sh pe-201530-master pe-201530-cm pe-201530-agent"
    echo "If no domain is provided puppetdebug.vlan is assumed"
    echo "Will do a monolithic install on the master node"
    echo "** This script currently only works in my local vms!"
    echo "** Would make more sense to run this with Beaker..."
fi

# should come from common.sh
#pushd pe_builds
#find -type d -name "puppet-enterprise-${FULL_VER?}-*${PLATFORM_STRING?}*" -printf "%f\n" | sort
#BUILD=$(find -type d -name "puppet-enterprise-${FULL_VER?}-*${PLATFORM_STRING?}*" -printf "%f\n" | sort | tail -n1)
#popd

if [ -z "$BUILD" ]; then
    echo "!! Failed to find a build"
fi

echo "* Installing $BUILD onto $mom"

set +e
ssh_on "$mom" "sudo /pe_builds/$BUILD/puppet-enterprise-installer -a /vagrant/answers/all-in-one.answers.txt 2>&1 | tee /vagrant/install.log"
ssh_on "$cm" "sudo /vagrant/frictionless.sh ${mom}"
ssh_on "$cm" 'sudo /usr/local/bin/puppet agent -t'
ssh_on "$mom" "sudo /usr/local/bin/puppet cert sign $cm"
./inject-classification-tool.sh "$mom"
ssh_on "$mom" "sudo ${ruby_bin}/ruby /usr/local/bin/classification-tool.rb compile install $cm"
ssh_on "$cm" "sudo /usr/local/bin/puppet agent -t"
ssh_on "$mom" 'sudo /usr/local/bin/puppet agent -t' # to set whitelists
ssh_on "$agent" "sudo /vagrant/frictionless.sh ${mom} main:server=$cm"
ssh_on "$agent" "sudo /usr/local/bin/puppet agent -t"
ssh_on "$mom" "sudo /usr/local/bin/puppet cert sign $agent"
ssh_on "$agent" "sudo /usr/local/bin/puppet agent -t"
