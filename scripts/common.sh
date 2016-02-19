# Common setup used by several scripts to determine VER, PLATFORM, PLATFORM_VERSION, ARCH from
# current directory, potentially with local overrides.
if [ -e local ]; then
    source local
fi
VER=${VER:-$(pwd | grep -Eo 'pe-[0-9]+\.[0-9]+' | grep -Eo '[0-9]+\.[0-9]+')}
FULL_VER=${FULL_VER:=${VER}.0}
defaults=($(basename "$(pwd)" | grep -Eo '[^-]+'))
PLATFORM=${PLATFORM:-${defaults[0]}}
case "${PLATFORM?}" in
    redhat | centos | sles)
        PLATFORM=el
        default_arch=x86_64
        ;;
    debian | ubuntu)
        default_arch=amd64
        defaults[1]=$(echo ${defaults[1]} | sed -re 's/([0-9]{2})(.+)/\1.\2/')
        ;;
esac
PLATFORM_VERSION=${PLATFORM_VERSION:-${defaults[1]}}
ARCH=${ARCH:-$default_arch}
PLATFORM_STRING="${PLATFORM?}-${PLATFORM_VERSION?}-${ARCH?}"
BUILD=$(find -type d -name "puppet-enterprise-${FULL_VER?}-*-${PLATFORM_STRING?}*" -printf "%f\n" | sort | tail -n1)
echo "VER: $VER"
echo "FULL_VER: $FULL_VER"
echo "PLATFORM_STRING: $PLATFORM_STRING"
echo "BUILD: $BUILD"

ensure_rsync() {
    _platform=${1?}
    _host=${2?}

    case "${_platform%%-*}" in
        el | redhat | centos)
            ssh_on ${_host?} 'yum install -y rsync tree wget'
            ;;
        ubuntu | debian)
            ssh_on ${_host?} 'apt-get install -y rsync tree wget'
            ;;
        *)
            echo 'no sles yet!'
            exit 1
    esac
}

ssh_on() {
    _host=${1?}
    _command=${2?}

    echo "--> ($_host)# $_command"

    if [[ "$_host" =~ .*\.puppetdebug\.vlan ]]; then
        _hostname=${_host%%.*}
        pwd
        vagrant ssh $_hostname -c "sudo $_command"
    else
        # accept master's host key since it's just a qa vm
        ssh -o StrictHostKeyChecking=no root@${_host} "$_command"
    fi    
}

rsync_on() {
    _host=${1?}
    _source=${2?}
    _target=${3}

    if [[ "$_host" =~ .*\.puppetdebug\.vlan ]]; then
        _port=$(vagrant ssh-config ${_host%%.*} | grep Port | grep -oE '[0-9]+')
        rsync --progress -rLptgoD -e "ssh -o StrictHostKeyChecking=false -p $_port" $_source root@localhost:${_target}
    else
        rsync --progress -rLptgOD $_source root@${_host}:${_target}
    fi
}
