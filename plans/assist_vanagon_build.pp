# This plan is a very special case for vanagon build's of packages like
# pe-postgresql-pglogical or pe-postgresql-pgrepack which require pe-postgresql*
# package dependencies installed on the vanagon build host in order to build.
#
# Normally, these packages are downloaded by Vanagon automatically from artifactory,
# but in cases where you are in the midst of updating the puppet-enterprise-vanagon
# codebase defining how pe-postgresql* packages are built, they don't exist yet
# in artifactory, and you need to inject them onto the vanagon host.
plan meep_tools::assist_vanagon_build(
  TargetSpec $nodes,
  Enum['96','10','11'] $postgres_version,
  # Absolute path to the local Vanagon directory containing pre-built
  # pe-postgreql packages.
  Enterprise_tasks::Absolute_path $output_dir,
) {
  apply_prep($nodes)
  run_plan(facts, nodes =>  $nodes)

  get_targets($nodes).each |$node| {
    $vanagon_vars = meep_tools::get_vanagon_output_vars($node.facts['os'])
    $ext = $vanagon_vars['ext']
    $sep = $vanagon_vars['sep']
    $platform = $vanagon_vars['platform']
    $provider = $vanagon_vars['provider']
    $package_dir = "${output_dir}/${vanagon_vars['package_dir']}"

    $package_version = meep_tools::lookup_package_version($package_dir, "pe-postgresql${postgres_version}-server*.${ext}")
    debug("package_version: ${package_version}")

    $common_version = meep_tools::lookup_package_version($package_dir, "pe-postgresql-common*.${ext}")
    debug("common_version: ${common_version}")

    # For some reason, packages built by puppet-enterprise-vanagon have this
    # extra string...
    $pe_vanagon_sep = ($osfacts['family'] in ['RedHat','SLES','Suse']) ? {
      true    => '.pe.',
      default => '.',
    }
    # Ex: pe-postgresql-common-2019.1-1.pe.el7.x86_64.rpm
    $postgresql_common  = "pe-postgresql-common${sep}${common_version}${pe_vanagon_sep}${platform}.${ext}"
    # Ex: pe-postgresql96-2019.1.9.6.10-2${pe_vanagon_sep}el7.x86_64.rpm
    $postgresql         = "pe-postgresql${postgres_version}${sep}${package_version}${pe_vanagon_sep}${platform}.${ext}"
    $postgresql_server  = "pe-postgresql${postgres_version}-server${sep}${package_version}${pe_vanagon_sep}${platform}.${ext}"
    $postgresql_contrib = "pe-postgresql${postgres_version}-contrib${sep}${package_version}${pe_vanagon_sep}${platform}.${ext}"
    $postgresql_devel   = "pe-postgresql${postgres_version}-devel${sep}${package_version}${pe_vanagon_sep}${platform}.${ext}"

    [
      $postgresql_common,
      $postgresql,
      $postgresql_server,
      $postgresql_contrib,
      $postgresql_devel,
    ].each |$package_name| {
      upload_file("${package_dir}/${package_name}", "/root/${package_name}", $node)
    }

    apply($node) {
      $additional_options = $osfamily == 'Debian' ? {
        true  => { 'install_options' => '--allow-unauthenticated' },
        false => {},
      }
      package { 'pe-puppet-enterprise-release':
        ensure => present,
        *      => $additional_options,
      }
      debug("osfamily: ${osfamily}")
      debug("_osfamily: ${_osfamily}")

      if $osfamily == 'Debian' {
        # 16.04: comerr-dev krb5-multidev libgssrpc4 libkadm5clnt-mit9 libkadm5srv-mit9 libkdb5-8 libkrb5-dev
        # 18.04: comerr-dev krb5-multidev libcom-err2 libgssapi-krb5-2 libgssrpc4 libk5crypto3 libkadm5clnt-mit11 libkadm5srv-mit11 libkdb5-9 libkrb5-3 libkrb5-dev libkrb5support0
        package { ['comerr-dev', 'krb5-multidev', 'libossp-uuid16', 'libkrb5-dev']:
          ensure => present,
        }
      }

      package { "pe-postgresql-common":
        ensure   => present,
        provider => $provider,
        source   => "/root/$postgresql_common",
      }
      -> package { "pe-postgresql${postgres_version}":
        ensure   => present,
        provider => $provider,
        source   => "/root/$postgresql",
      }
      -> package { "pe-postgresql${postgres_version}-server":
        ensure   => present,
        provider => $provider,
        source   => "/root/$postgresql_server",
      }
      -> package { "pe-postgresql${postgres_version}-contrib":
        ensure   => present,
        provider => $provider,
        source   => "/root/$postgresql_contrib",
      }
      -> package { "pe-postgresql${postgres_version}-devel":
        ensure   => present,
        provider => $provider,
        source   => "/root/$postgresql_devel",
      }
    }
  }
}
