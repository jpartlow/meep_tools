plan integration::prep_pe(
  TargetSpec $nodes,
  Pattern[/^\d{4}\.\d+$/] $pe_family,
  Variant[Enum['latest'],Pattern[/^\d{4}\.\d+\.\d+.*/]] $pe_version = 'latest',
) {
  run_plan(facts, nodes => $nodes)

  if $pe_version == 'latest' {
    $ci_ready_url = "http://enterprise.delivery.puppetlabs.net/${pe_family}/ci-ready"
    $curl_of_latest_result = run_command("curl ${ci_ready_url}/LATEST", 'localhost').first()
    $_pe_version = $curl_of_latest_result.value()['stdout'][0,-2]
  } else {
    $_pe_version = $pe_version
  }
  debug("pe_version ${_pe_version}")

  get_targets($nodes).each |$node| {
    debug("node: ${node} ${node.facts}")

    $platform_tag = integration::platform_tag($node.facts['os'])
    debug("platform_tag ${platform_tag}")

    $get_pe_result = run_task(integration::get_pe, $node, 'platform_tag'          => $platform_tag, 'version' => $_pe_version).first()
    $pe_dir = $get_pe_result.value()['pe_dir']

    $check_pe_conf_result = run_command("ls /root/pe.conf", $node, '_catch_errors' => true).first()
    debug($check_pe_conf_result)
    if !$check_pe_conf_result.ok() {
      file::write("/tmp/tmp.${_pe_version}.pe.conf", "\"puppet_enterprise::puppet_master_host\": \"${node.name}\"")
      upload_file("/tmp/tmp.${_pe_version}.pe.conf", "/root/pe.conf", $node)
    }
    run_command("./${pe_dir}/puppet-enterprise-installer -c /root/pe.conf -p", $node)
  }
}
