function integration::platform_tag(Hash $osfacts) {
    $os_family = $osfacts['family']
    $os_major  = $osfacts['release']['major']
    case $os_family {
      'RedHat': {
        "el-${os_major}-x86_64"
      }
      'Debian': {
        "ubuntu-${osfacts['release']['full']}-amd64"
      }
      'SLES': {
        "sles-${os_major}-x86_64"
      }
      default: {
        fail("Unknown os family: ${os_family}")
      }
    }
}
