# Mount workstation source directory via nfs into each of the given target hosts.
plan meep_tools::nfs_mount(
  TargetSpec $nodes,
  String $source_dir     = 'work/src',
  Optional[Meep_tools::Ip4] $workstation_ip = undef,
) {
  $user = system::env('USER')
  $home = system::env('HOME')
  $uid = run_command('id -u', 'localhost', '_run_as' => $user)
  $gid = run_command('id -g', 'localhost', '_run_as' => $user)

  $target_mount_dir = "/${user}-src"
  $_source_dir = "${home}/$source_dir"

  # Using Boltdir/inventory.yaml to provide configuration defaults for localhost
  # since hiera is not (yet?) available for plans (outside of apply blocks).
  $localhost = get_targets('localhost')[0]
  $_workstation_ip = $workstation_ip == undef ? {
    true  => $localhost.vars()['workstation_ip'],
    false => $workstation_ip,
  }
  debug("workstation_ip: ${_workstation_ip}")

  get_targets($nodes).each |$target| {
    $get_ip_result = run_task(meep_tools::get_ip_addr, $target).first()
    $target_ip = $get_ip_result.value()['address']
    debug("target_ip: ${target_ip}")

    run_task(meep_tools::add_nfs_exports, localhost,
      'source_dir' => $_source_dir,
      'target_ip'  => $target_ip,
      'user_id'    => $uid,
      'group_id'   => $gid,
    )
    run_task(meep_tools::mount_nfs_dir, $target,
      'source_ip'      => $_workstation_ip,
      'source_dir'     => $_source_dir,
      'local_mount_dir'  => $target_mount_dir
    )
  }
}
