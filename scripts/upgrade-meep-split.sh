source common.sh

get_hostnames

####################
## !! Try upgrading db first for 2015.2.3 orchestration-services upgrade failure
## !!!!!!
#ssh_on "$db" "/vagrant/do-pem-install.sh -p /pe_builds/${BUILD?}"
#grep -E '^\* returned: 2' "install-pem-${db%%.puppetdebug.vlan}-${BUILD?}.log" || exit 1

ssh_on "$master" "/vagrant/do-pem-install.sh -p /pe_builds/${BUILD?}"
grep -E '^\* returned: 2' "install-pem-${master%%.puppetdebug.vlan}-${BUILD?}.log" || exit 1

ssh_on "$db" "/vagrant/do-pem-install.sh -p /pe_builds/${BUILD?}"
grep -E '^\* returned: 2' "install-pem-${db%%.puppetdebug.vlan}-${BUILD?}.log" || exit 1

ssh_on "$console" "/vagrant/do-pem-install.sh -p /pe_builds/${BUILD?}"
grep -E '^\* returned: 2' "install-pem-${console%%.puppetdebug.vlan}-${BUILD?}.log" || exit 1

ssh_on "$master" "/opt/puppetlabs/puppet/bin/puppet agent -t 2>&1 | tee /vagrant/second-agent-run-post-upgrade-master.log"
ssh_on "$db" "/opt/puppetlabs/puppet/bin/puppet agent -t 2>&1 | tee /vagrant/second-agent-run-post-upgrade-db.log"
ssh_on "$console" "/opt/puppetlabs/puppet/bin/puppet agent -t 2>&1 | tee /vagrant/second-agent-run-post-upgrade-console.log"
ssh_on "$agent" "/opt/puppetlabs/puppet/bin/puppet agent -t 2>&1 | tee /vagrant/second-agent-run-post-upgrade-agent.log"

# Disable puppet agent after full upgrade is completed so that we don't have
# random puppet-agent runs interferring with state
# This doesn't prevent puppet-agent runs kicked off by re-enabling puppet-agent
# in the installer-shim from having complicated the upgrade process.
ssh_on "$master" "/opt/puppetlabs/puppet/bin/puppet resource service puppet ensure=stopped enable=false"
ssh_on "$db" "/opt/puppetlabs/puppet/bin/puppet resource service puppet ensure=stopped enable=false"
ssh_on "$console" "/opt/puppetlabs/puppet/bin/puppet resource service puppet ensure=stopped enable=false"
