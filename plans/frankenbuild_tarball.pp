plan meep_tools::frankenbuild_tarball(
  TargetSpec $node = 'localhost',
  String $platform,
  String $pe_family,
  Integer $pem_pr,
  Enterprise_tasks::Absolute_path $pe_builds_dir, 
) {
  run_plan('enterprise_tasks::create_tempdirs', 'nodes' => $node)

  $target = get_targets($node)[0]
  $workdir = $target.vars['workdir']

  run_command("git clone git@github.com:puppetlabs/frankenbuilder ${workdir}/frankenbuilder", $target)
  run_command("cd ${workdir}/frankenbuilder; ./frankenbuilder ${pe_family} --workdir=${workdir}/frankenmodules --platform=${platform} --puppet-enterprise-module-pr=${pem_pr}", $target)
  run_command("mv ${workdir}/frankenbuilder/frankenbuild/puppet-enterprise-${pe_family}*.tar.gz ${pe_builds_dir}", $target)
  run_command("rm -rf ${workdir}", $target)
}
