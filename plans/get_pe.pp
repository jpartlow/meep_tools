# Downloads and unpacks a PE tarball for the appropriate platform onto each of
# the nodes.
#
# @return Array[Result] of the results returned by the get_pe task for each node.
plan meep_tools::get_pe(
  TargetSpec $nodes,
  Optional[Meep_tools::Pe_family] $pe_family = undef,
  Meep_tools::Pe_version $pe_version = 'latest',
) {

  if $pe_family == undef and $pe_version == 'latest' {
    fail_plan("If you do not supply 'pe_family', then you must supply an exact 'pe_version'.")
  }

  run_plan(facts, nodes => $nodes)

  if $pe_version == 'latest' {
    $ci_ready_url = "http://enterprise.delivery.puppetlabs.net/${pe_family}/ci-ready"
    $curl_of_latest_result = run_command("curl ${ci_ready_url}/LATEST", 'localhost').first()
    $_pe_version = $curl_of_latest_result.value()['stdout'][0,-2]
  } else {
    $_pe_version = $pe_version
  }
  debug("pe_version ${_pe_version}")

  # Return an Array of the Results returned by run_task for the get_pe task.
  return get_targets($nodes).map |$node| {
    debug("node: ${node} ${node.facts}")

    $platform_tag = meep_tools::platform_tag($node.facts['os'])
    debug("platform_tag ${platform_tag}")

    run_task(meep_tools::get_pe, $node, 'platform_tag' => $platform_tag, 'version' => $_pe_version).first()
  }
}
