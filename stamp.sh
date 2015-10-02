#! /usr/bin/env bash

set -e

platform=$1
version=$2
mono_or_split=$3

if [[ -z $platform || -z $version || -z $mono_or_split ]]; then
    echo "Usage: stamp.sh <platform> <pe-version> <mono-or-split>"
    echo "    platform => 'centos-6', 'ubuntu-1204' or similar"
    echo "    pe-version => 'pe-3.8', 'pe-3.99', etc."
    echo "    mono-or-split => 'mono' or 'split' for the install"
    exit 1
fi

repodir="$platform-$mono_or_split"
mkdir -p $version

cd $version
if [ ! -e "$repodir/.git" ]; then
  git clone git@github.com:jpartlow/puppet-debugging-kit $repodir
  pushd $repodir
  git checkout integration
  popd
fi

cd $repodir

if [ ! -e src/puppetlabs ]; then
  echo "* linking src"
  mkdir src
  pushd src
  ln -s /home/jpartlow/work/src/pl puppetlabs
  popd
fi
if [ ! -e pe_builds ]; then
  echo "* linking pe_builds"
  ln -s /home/jpartlow/.vagrant.d/pe_builds pe_builds
fi
for script in /home/jpartlow/work/virtual/scripts/*.{sh,rb}; do
  scriptname=$(basename $script)
  if [ ! -e "$scriptname" ]; then
    echo "* linking $script"
    ln -s $script $scriptname
  fi
done

# generate an ssh key to be added to vm root .ssh for split installs using higgs
#[[ "$mono_or_split" == 'split' && ! -e insecure_ssh_key ]] && ssh-keygen -b2048 -trsa -N "" -f insecure_ssh_key
# not necessary, can use the .vagrant/machines/<hostname>/virtualbox/private_key files instead
# But for pe_acceptance_tests runs, it is helpful to have my public key available
cp ~/.ssh/id_rsa.pub .
