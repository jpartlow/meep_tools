source common.sh

get_hostnames

ssh_on "$master" "/vagrant/do-pem-install.sh"
ssh_on "$master" "/opt/puppetlabs/puppet/bin/puppet resource service puppet ensure=stopped enable=false"
ssh_on "$db" "/vagrant/do-pem-install.sh"
ssh_on "$db" "/opt/puppetlabs/puppet/bin/puppet resource service puppet ensure=stopped enable=false"
ssh_on "$console" "/vagrant/do-pem-install.sh"
ssh_on "$console" "/opt/puppetlabs/puppet/bin/puppet resource service puppet ensure=stopped enable=false"

ssh_on "$master" "/opt/puppetlabs/puppet/bin/puppet agent -t 2>&1 | tee /vagrant/second-agent-run-post-upgrade-master.log"
ssh_on "$db" "/opt/puppetlabs/puppet/bin/puppet agent -t 2>&1 | tee /vagrant/second-agent-run-post-upgrade-db.log"
ssh_on "$console" "/opt/puppetlabs/puppet/bin/puppet agent -t 2>&1 | tee /vagrant/second-agent-run-post-upgrade-console.log"
ssh_on "$agent" "/opt/puppetlabs/puppet/bin/puppet agent -t 2>&1 | tee /vagrant/second-agent-run-post-upgrade-agent.log"
