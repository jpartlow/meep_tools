# For each node, copies all of the packages built in the given vanagon output
# directory for the node's platform into the packages directory of the /root PE
# tarball matching the given pe_family.
#
# Packages are signed using the frankenbuilder gpg key, and the tarball's
# package repository metadata is rebuilt so that we can install with the custom
# built packages.
plan meep_tools::inject_packages(
  TargetSpec $nodes,
  Enterprise_tasks::Pe_family $pe_family,
  Enum['96','10','11'] $postgres_version,
  # Absolute path to the local Vanagon directory containing pre-built
  # pe-postgreql packages.
  Enterprise_tasks::Absolute_path $output_dir,
) {
  run_plan(facts, nodes => $nodes)

  get_targets($nodes).each |$node| {
    $osfacts = $node.facts['os']
    $_platform_tag = enterprise_tasks::platform_tag($osfacts)
    $vanagon_vars = meep_tools::get_vanagon_output_vars($osfacts)
    $ext = $vanagon_vars['ext']
    $sep = $vanagon_vars['sep']
    $package_platform_string = $vanagon_vars['platform']
    $provider = $vanagon_vars['provider']
    $package_dir = "${output_dir}/${vanagon_vars['package_dir']}"

    # Find the directory of the latest /root PE tarball matching our $pe_family
    $_find_dir_result = run_command("find /root -type d -name 'puppet-enterprise-${pe_family}*${_platform_tag}' | sort | tail -1", $node).first()
    $pe_dir = $_find_dir_result.value()['stdout'][0,-2] # strip cr
    if $pe_dir == '' {
      fail_plan("Did not find any $pe_family tarballs in /root on $node")
    }
    notice("Injecting packages into ${pe_dir}")
    $pe_package_dir="${pe_dir}/packages/${_platform_tag}"

    # Import the frankenbuilder gpg key so we can sign packages or metadata
    [
      'GPG-KEY-frankenbuilder',
      'GPG-KEY-frankenbuilder.pub',
    ].each |$file_name| {
      upload_file("meep_tools/gpg/${file_name}", "/root/${file_name}", $node)
    }
    $_gpg_result = run_command("gpg --import /root/GPG-KEY-frankenbuilder", $node, '_catch_errors' => true).first()
    # gpg --import returns 2 when key is already present
    if $_gpg_result.error() and $_gpg_result['exit_code'] != 2 {
      fail_plan($_gpg_result)
    }

    # Copy local vanagon packages into the tarball
    $postgres_package_version  = meep_tools::lookup_package_version($package_dir, "pe-postgresql${postgres_version}-server")
    $common_package_version    = meep_tools::lookup_package_version($package_dir, "pe-postgresql-common")
    $pglogical_package_version = meep_tools::lookup_package_version($package_dir, "pe-postgresql${postgres_version}-pglogical")
    $pgrepack_package_version  = meep_tools::lookup_package_version($package_dir, "pe-postgresql${postgres_version}-pgrepack")

    $packages = [
      "pe-postgresql-common${sep}${common_package_version}${package_platform_string}.${ext}",
      "pe-postgresql${postgres_version}${sep}${postgres_package_version}${package_platform_string}.${ext}",
      "pe-postgresql${postgres_version}-server${sep}${postgres_package_version}${package_platform_string}.${ext}",
      "pe-postgresql${postgres_version}-contrib${sep}${postgres_package_version}${package_platform_string}.${ext}",
      "pe-postgresql${postgres_version}-devel${sep}${postgres_package_version}${package_platform_string}.${ext}",
      "pe-postgresql${postgres_version}-pglogical${sep}${pglogical_package_version}${package_platform_string}.${ext}",
      "pe-postgresql${postgres_version}-pgrepack${sep}${pgrepack_package_version}${package_platform_string}.${ext}",
    ]
    debug("packages: ${packages}")

    $packages.each() |$name| {
      upload_file("${package_dir}/${name}", "${pe_package_dir}/${name}", $node)
    }

    $signing_params = case $osfacts['family'] {
      'RedHat': {
        {
          'repo_dir'         => $pe_package_dir,
          'packages'         => $packages.join(' '),
          'os_major_version' => $osfacts['release']['major'],
        }
      }
      'SLES','Suse': {
        {
          'repo_dir' => $pe_package_dir,
        }
      }
      'Debian': {
        {
          'repo_dir' => $pe_package_dir,
          'codename' => meep_tools::ubuntu_codename($osfacts['release']['full']),
        }
      }
      default: {
        fail_plan("Unable to sign packages for os: ${osfacts}")
      }
    }

    # Set the os family as a feature on the node so that the correct
    # implementation of sign_and_update_repo is found.
    set_feature($node,
      $osfacts['family'] ? {
        'Suse'  => 'SLES',
        default =>  $osfacts['family']
      }
    )
    run_task(meep_tools::sign_and_update_repo, $node, $signing_params)
  }
}
