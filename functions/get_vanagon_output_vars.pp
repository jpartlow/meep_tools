# @param osfacts [Hash] the facter 'os' facts hash from a node.
# @return [Hash] of values describing the vanagon output structure for the
#   platform described by the passed osfacts.
#
#   'package_dir': the relative path within a vanagon output dir to the
#     packages built for this platform. 
#   'ext': the package extension (rpm or deb)
#   'sep': the separator string used in the package name (- or _)
#   'platform': the el or debian or sles specific platform string used in the
#     package name
#   'provider': the Puppet provider required to manually install a local
#     package (rpm or dpkg)
function meep_tools::get_vanagon_output_vars(Hash $osfacts) {
  $_osfamily = $osfacts['family']
  $_osmajor  = $osfacts['release']['major']
  $_osfull   = $osfacts['release']['full']

  case $_osfamily {
    'RedHat': {
      {
        'package_dir' => "el/${_osmajor}/products/x86_64",
        'ext'         => 'rpm',
        'sep'         => '-',
        'platform'    => "el${_osmajor}.x86_64",
        'provider'    => 'rpm',
      }
    }

    'Debian': {
      $codename = meep_tools::ubuntu_codename($_osfull)
      # The throwaway $_result is sidestepping a parser error
      $_result = {
        'package_dir' => "deb/${codename}",
        'ext'         => 'deb',
        'sep'         => '_',
        'platform'    => "${codename}_amd64",
        'provider'    => 'dpkg',
      }
    }

    'SLES','Suse': {
      {
        'package_dir' => "sles/${_osmajor}/products/x86_64",
        'ext'         => 'rpm',
        'sep'         => '-',
        'platform'    => "sles${_osmajor}.x86_64",
        'provider'    => 'rpm',
      }
    }

    default: {
      fail("Unknown os family '${_osfamily}'")
    }
  }
}
