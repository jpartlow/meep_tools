plan meep_tools::prep_pe(
  TargetSpec $nodes,
  Optional[Meep_tools::Pe_family] $pe_family = undef,
  Meep_tools::Pe_version $pe_version = 'latest',
) {
  $get_pe_results = run_plan(meep_tools::get_pe, 'nodes' => $nodes, 'pe_family' => $pe_family, 'pe_version' => $pe_version) 

  get_targets($nodes).each |$node| {

    $get_pe_result = $get_pe_results.filter |$result| { $result.target() == $node }[0]
    $pe_dir = $get_pe_result['pe_dir']
    $pe_version = $get_pe_result['pe_version']

    $check_pe_conf_result = run_command("ls /root/pe.conf", $node, '_catch_errors' => true).first()
    debug($check_pe_conf_result)
    if !$check_pe_conf_result.ok() {
      file::write("/tmp/tmp.${pe_version}.pe.conf", "\"puppet_enterprise::puppet_master_host\": \"${node.name}\"")
      upload_file("/tmp/tmp.${pe_version}.pe.conf", "/root/pe.conf", $node)
    }
    run_command("./${pe_dir}/puppet-enterprise-installer -c /root/pe.conf -p", $node)
  }
}
