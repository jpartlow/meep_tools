# @param full_version Pattern[/\d+\.\d+/] The Ubuntu version (18.04, etc.)
# @return [String] The codename for the release (bionic, etc.)
function meep_tools::ubuntu_codename(Pattern[/\d+\.\d+/] $full_version) {
  case $full_version {
    '18.04': { 'bionic' }
    '16.04': { 'xenial' }
    default: {
      fail("Unknown Ubuntu os release codename for '${full_version}'")
    }
  }
}
