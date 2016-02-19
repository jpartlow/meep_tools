set -e
#set -x

pe_builds_dir=~/.vagrant.d/pe_builds
vm_dir=~/work/virtual
pe_version='2015.3.0'
pe_family=${pe_version%.*}
os='centos'
os_version='7'
platform='el'
arch='x86_64'
layout='mono'
platform_string="${platform}-${os_version}-${arch}"

pushd "$vm_dir/pe-$pe_family/$os-$os_version-$layout"
./update-build.sh
popd

rm -rf "./puppet-enterprise-$pe_version-*"

pushd "$pe_builds_dir"
BUILD=$(find -type d -name "puppet-enterprise-${pe_version?}-*-${platform_string?}*" -printf "%f\n" | sort | tail -n1)
popd

rsync -a "$pe_builds_dir/$BUILD" .

if [ "$(ls -A ./packages)" ]; then # not empty
    packages_dir="$BUILD/packages/${platform_string?}"
    cp -r packages/* "${packages_dir?}"
    pushd "${packages_dir?}"
        createrepo --update .
    popd
    
    for package in packages/*; do
        regex='s/^packages\/([a-z-]+)-([0-9.]+)-.*$/\1,\2/p'
        package_name=$(echo "$package" | sed -rne "$regex" | cut -d, -f1)
        package_version=$(echo "$package" | sed -rne "$regex" | cut -d, -f2)
        modify_version="
require 'json'

filename = '${BUILD?}/packages/${platform_string?}-package-versions.json'
file = File.new(filename)
versions_json = JSON.load(file)
versions_json['${package_name?}']['version'] = '${package_version?}'
File.open(file, 'w') do |f|
    f.puts(JSON.pretty_generate(versions_json))
end
"
        ruby -e "${modify_version?}"
    done
fi

tar -czf "${BUILD}.tar.gz" "$BUILD"
