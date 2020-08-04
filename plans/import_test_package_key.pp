# Upload the module's gpg.pub key (borrowed from frankenbuilder).
# Import the key into the each node's package manager.
# Allows test packages injected into PE tarballs, signed with this key
# to be installed.
plan meep_tools::import_test_package_key(
  TargetSpec $nodes,
  String $public_key = 'GPG-KEY-frankenbuilder.pub', 
) {
  run_plan(facts, targets => $nodes)
  upload_file("meep_tools/gpg/${public_key}", "/root/${public_key}", $nodes)
  get_targets($nodes).each |$node| {
    $osfacts = $node.facts['os']
    $command = case $osfacts['family'] {
      'RedHat', 'SLES', 'Suse': {
        "rpm --import /root/${public_key}"
      }
      'Debian': {
        "cat /root/GPG-KEY-frankenbuilder.pub | apt-key add -"
      }
      default: {
        fail_plan("Unable to import packaging key for os: ${osfacts}")
      }
    }
    run_command($command, $node)
  }
}
