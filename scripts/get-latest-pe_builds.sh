#set -x
. common.sh
LATEST=$(curl "http://enterprise.delivery.puppetlabs.net/$VER/ci-ready/LATEST")

cd pe_builds
rm -rf "puppet-enterprise-${VER}.0*"

BUILD="puppet-enterprise-${LATEST?}-${PLATFORM_STRING?}.tar"
wget "http://enterprise.delivery.puppetlabs.net/$VER/ci-ready/$BUILD"
tar -xf "$BUILD"
gzip "$BUILD"
