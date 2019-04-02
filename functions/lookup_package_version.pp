function meep_tools::lookup_package_version(
  Meep_tools::Absolute_path $package_dir,
  String $package_name,
) {
  $find_result = run_command("find ${package_dir} -name ${package_name}* | grep -oE '[.0-9]+-[0-9]' | sort | tail -n1", 'localhost').first()
  $find_result.value()['stdout'][0,-2] # strip cr
}
