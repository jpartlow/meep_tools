LOGFILE=/tmp/loop-test.log

run() {
  local message=$1
  local command=$2
  local pause=$3
  local fail=$4
  
  local ts
  ts=$(date +%Y-%m-%dT%H:%M:%S.%N%z)

  echo -e "\e[34m${ts} * ${message}\e[0m" | tee -a "$LOGFILE"

  echo -e "\e[35m * executing: \`${command}\`" | tee -a "$LOGFILE"
  eval "$command" | tee -a "$LOGFILE"
  if [ "${PIPESTATUS[0]}" -ne 0 ] && [ "$fail" = 'yes' ]; then
    exit 1
  fi

  echo -e "\e[34m * Pausing for ${pause} seconds\e[0m" | tee -a "$LOGFILE"
  echo | tee -a "$LOGFILE"
  sleep "$pause"
}

cert_regen() {
  run "(1) Stopping puppet" "puppet resource service puppet ensure=stopped" 0
  run "(1) Stopping pxp"    "puppet resource service pxp-agent ensure=stopped" 0
  run "(2) Backing up ssl dir" "cp -r /etc/puppetlabs/puppet/ssl/ /etc/puppetlabs/puppet/ssl_bak/" 0
  run "(3) Clearing cached catalog" "rm -f /opt/puppetlabs/puppet/cache/client_data/catalog/fl8e3p6tmb2lx6n.delivery.puppetlabs.net.json" 0
  run "(4) Calling puppetserver ca clean" "puppetserver ca clean --certname fl8e3p6tmb2lx6n.delivery.puppetlabs.net" 0
  run "(5) Clearing out any left over pem files" "find /etc/puppetlabs/puppet/ssl -name fl8e3p6tmb2lx6n.delivery.puppetlabs.net.pem -delete" 0
  local timestamp
  timestamp=$(date +%s)
  run "(6) Add DNS alt name" "sed -i -e \"/puppet_master_dnsaltnames/ s/foo\..*bar/foo.${timestamp}.bar/\" /etc/puppetlabs/enterprise/conf.d/pe.conf" 0
  run "(6a) Run recover_configuration to try and reproduce bug (cert request generating keys)" "puppet infra recover_configuration" 0
  run "(6b) Check state of puppet service" "puppet resource service puppet" 0
  run "(6b) Check state of puppet service" "pgrep -a puppet"
  run "(6c) Check state of ssldir before calling puppet infra configure" "tree -ugpD /etc/puppetlabs/puppet/ssl" 0
  run "(7) Executing puppet infra configure" "puppet infrastructure configure --no-recover 2>&1 | tee regen-${timestamp}.log; [ \${PIPESTATUS[0]} -eq 0 ] || exit 1" 0 'yes'
  run "(8) Running puppet agent" "puppet agent --onetime --verbose --no-daemonize --no-usecacheonfailure --no-splay --show_diff || exit 2" 0 'yes'
}

restore() {
  local certname
  certname=$(facter fqdn)
  run "(1) Uninstall PE" "/root/puppet-enterprise*/puppet-enterprise-uninstaller -y -d -p" 0 'yes'
  run "(2) Create a pe.conf" "echo '\"puppet_enterprise::puppet_master_host\": \"${certname}\"' > /root/pe.conf" 0 'yes'
  run "(3) Reinstall PE" "/root/puppet-enterprise*/puppet-enterprise-installer -c /root/pe.conf" 0 'yes'
  run "(4) Restore from backup" "puppet-backup restore /root/backup.tgz --force" 0 'yes'
  run "(5) Running puppet agent" "puppet agent --onetime --verbose --no-daemonize --no-usecacheonfailure --no-splay --show_diff" 0 'yes'
}

# edit and choose a function to run.
restore
