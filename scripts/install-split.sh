source common.sh

version=$1
if [ -z "$version" ]; then
    echo "Usage; install-split.sh <version> [stage]*"
    echo "  version: 2015.3.3"
    echo "  stage: (optional) which stages of installation to do"
    echo "    all (all the stages below)"
    echo "    install - puppet-enterprise-installer"
    echo "    secondrun - secondary puppet agent run on nodes"
    echo "    agent - install agent and sign cert"
    echo "    snapshot - snapshot vms"
    exit 1
fi
shift

provision() {
  vagrant provision --provision-with=hosts
}

install() {
  get_hostnames
  ssh_on "$master" "/vagrant/do-install.sh $version master"
  ssh_on "$db" "/vagrant/do-install.sh $version puppetdb"
  ssh_on "$console" "/vagrant/do-install.sh $version console"
}

secondrun() {
  get_hostnames
  ssh_on "$master" "/opt/puppetlabs/puppet/bin/puppet agent -t"
  ssh_on "$db" "/opt/puppetlabs/puppet/bin/puppet agent -t"
  ssh_on "$console" "/opt/puppetlabs/puppet/bin/puppet agent -t"
}

agent() {
  get_hostnames
  ssh_on "$agent" "curl -k https://${master}:8140/packages/current/install.bash | sudo bash"
  ssh_on "$master" "/opt/puppetlabs/puppet/bin/puppet cert sign $agent"
  ssh_on "$agent" "/opt/puppetlabs/puppet/bin/puppet agent -t"
}

classifier() {
  inject-classification-tool.sh "${master}"
}

snapshot() {
  vagrant snap delete --name "pe-$version-installed"
  vagrant snap take --name "pe-$version-installed"
}

for stage in "${@:-all}"; do
  case $stage in
    all)
      provision
      install
      secondrun
      agent
      classifier
      snapshot
      ;;
    provision | install | secondrun | agent | classifier | snapshot)
      eval "$stage"
      ;;
  esac
done
