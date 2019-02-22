# This plan is a very special case for vanagon build's of packages like
# pe-postgresql-pglogical or pe-postgresql-pgrepack which require pe-postgresql*
# package dependencies installed on the vanagon build host in order to build.
#
# Normally, these packages are downloaded by Vanagon automatically from artifactory,
# but in cases where you are in the midst of updating the puppet-enterprise-vanagon
# codebase defining how pe-postgresql* packages are built, they don't exist yet
# in artifactory, and you need to inject them onto the vanagon host.
#
# So far, the only way I've found to do that is to through a pry into the middle of
# https://github.com/puppetlabs/vanagon/blob/0.15.19/lib/vanagon/driver.rb#L108
# to halt execution before vanagon tries to ensure the dependencies are installed,
# and then run this plan against the vanagon host to get the locally built
# packages installed.
plan meep_tools::assist_vanagon_build(
  TargetSpec $nodes,
  Enum['96','10','11'] $postgres_version,
  # Absolute path to the local Vanagon directory containing pre-built
  # pe-postgreql packages.
  Pattern[/^\/.*/] $output_dir,
) {
  apply_prep($nodes)
  run_plan(facts, nodes =>  $nodes)

  get_targets($nodes).each |$node| {
    $osfacts   = $node.facts['os']
    $_osfamily = $osfacts['family']
    $_osmajor  = $osfacts['release']['major']
    $_osfull   = $osfacts['release']['full']

    case $_osfamily {
      'RedHat': {
        $package_dir = "${output_dir}/el/${_osmajor}/products/x86_64"
        $ext = "rpm"
        $sep = '-'
        $platform = ".pe.el${_osmajor}.x86_64"
        $provider = "rpm"
      }
      'Debian': {
        $codename = case $_osfull {
          '18.04': { 'bionic' }
          '16.04': { 'xenial' }
          default: { fail("Unknown Ubuntu os release codename for '${_osfull}' for ${node}") }
        }
        $package_dir = "${output_dir}/deb/${codename}"
        $ext = "deb"
        $sep = '_'
        $platform = "${codename}_amd64"
        $provider = "dpkg"
      }
      'SLES','Suse': {
        $package_dir = "${output_dir}/sles/${_osmajor}/products/x86_64"
        $ext = "rpm"
        $sep = '-'
        $platform = ".pe.sles${_osmajor}.x86_64"
        $provider = "rpm"
      }
      default: {
        fail("Unknown os family '${_osfamily}' for ${node}")
      }
    }

    $find_result = run_command("find ${package_dir} -name 'pe-postgresql${postgres_version}-server*.${ext}' | grep -oE '[0-9]{4}\\.[0-9]+[.0-9]+-[0-9]'", 'localhost').first()
    $package_version = $find_result.value()['stdout'][0,-2]
    debug("package_version: ${package_version}")

    $postgresql         = "pe-postgresql${postgres_version}${sep}${package_version}${platform}.${ext}"
    $postgresql_server  = "pe-postgresql${postgres_version}-server${sep}${package_version}${platform}.${ext}"
    $postgresql_contrib = "pe-postgresql${postgres_version}-contrib${sep}${package_version}${platform}.${ext}"
    $postgresql_devel   = "pe-postgresql${postgres_version}-devel${sep}${package_version}${platform}.${ext}"

    [
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

      package { "pe-postgresql${postgres_version}":
        ensure   => present,
        provider => $provider,
        source   => $postgresql,
      }
      -> package { "pe-postgresql${postgres_version}-server":
        ensure   =>  present,
        provider =>  $provider,
        source   => $postgresql_server,
      }
      -> package { "pe-postgresql${postgres_version}-contrib":
        ensure   =>  present,
        provider =>  $provider,
        source   => $postgresql_contrib,
      }
      -> package { "pe-postgresql${postgres_version}-devel":
        ensure   =>  present,
        provider =>  $provider,
        source   => $postgresql_devel,
      }
    }
  }
}
