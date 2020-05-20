plan meep_tools::build_pg_extension(
  TargetSpec $nodes,
  Enum['pglogical','pgrepack'] $extension,
  Enterprise_tasks::Pe_family $pe_family,
  Variant[Enterprise_tasks::Pe_version,Enum['latest']] $pe_version = 'latest',
  Enum['96','10','11'] $postgres_version,
  Enterprise_tasks::Absolute_path $puppet_enterprise_vanagon_dir,
) {
  # This gets a PE tarball onto the node, unpacks and runs the installer in -p
  # prep mode which just sets up packaging.
  run_plan('meep_tools::prep_pe',
    nodes      => $nodes,
    pe_family  => $pe_family,
    pe_version => $pe_version
  )

  # Because PE packages are now available thanks to the previous plan,
  # this plan can now install the base pe-puppet-enterprise-release,
  # copy the locally generated postgresql packages and install those as well.
  run_plan('meep_tools::assist_vanagon_build',
    nodes            => $nodes,
    postgres_version => $postgres_version,
    output_dir       => "${puppet_enterprise_vanagon_dir}/output"
  )

  # Run vanagon locally, but pass it the prepared node.
  run_plan(facts, targets =>  $nodes)
  get_targets($nodes).each |$node| {
    $platform_tag = enterprise_tasks::platform_tag($node.facts['os'])
    run_command("cd ${puppet_enterprise_vanagon_dir}; bundle exec build pe-postgresql${postgres_version}-${extension} ${platform_tag} ${node.name} --engine base", 'localhost')
  }
}
