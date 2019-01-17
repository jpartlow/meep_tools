# Mount workstation source directory via nfs into each of the given target hosts.
plan integration::nfs_mount(
  TargetSpec $nodes,
  String $source_dir     = '/home/jpartlow/work/src',
  String $target_mount_dir = '/jpartlow-src',
  Optional[Integration::Ip4] $workstation_ip = undef,
) {
  # Using Boltdir/inventory.yaml to provide configuration defaults for localhost
  # since hiera is not (yet?) available for plans (outside of apply blocks).
  $localhost = get_targets('localhost')[0]
  $_workstation_ip = $workstation_ip == undef ? {
    true  => $localhost.vars()['workstation_ip'],
    false => $workstation_ip,
  }
  debug("workstation_ip: ${_workstation_ip}")

  get_targets($nodes).each |$target| {
    $get_ip_result = run_task(integration::get_ip_addr, $target).first()
    $target_ip = $get_ip_result.value()['address']
    debug("target_ip: ${target_ip}")

    run_task(integration::add_nfs_exports, localhost,
      'source_dir' => $source_dir,
      'target_ip'  => $target_ip
    )
    run_task(integration::mount_nfs_dir, $target,
      'source_ip'      => $_workstation_ip,
      'source_dir'     => $source_dir,
      'local_mount_dir'  => $target_mount_dir
    )
  }
}
