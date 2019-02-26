Various utility scripts cobbled together for installer dev work.

# Setup

This repository is a Puppet module, with some standalone scripts and a number
of Bolt plans and tasks.

In order to make use of the Bolt plans and tasks, your local installation of
Bolt needs to be aware of the module.

For my use, I did the following:

1. Ensure puppet-bolt is installed
   * If dpkg/yum doesn't yet have repo configuration that can find a current
     puppet-bolt, then wget and install an appropriate puppet-release package
from apt.puppetlabs.com or yum.puppetlabs.com
   * Once that's installed, yum or apt install puppet-bolt
1. Configure your bolt modulepath
   * Update (probably create) your .puppetlabs/bolt/bolt.yaml

```yaml
modulepath: "<HOME>/.puppetlabs/bolt-code/modules"
format: human
ssh:
  host-key-check: false
  user: root
```

(Update you're \<HOME\> path). The modulepath is key, it does not have to be
.puppetlabs/bolt-code/modules, but Bolt needs to know where to find modules
that you want to run plans and tasks from.

1. Once that is set up, symlink meep_tools into the modules dir listed in the
   modulepath.

You should now be able to `bolt plan show` and see several meep_tools::
namespaced plans listed, such as meep_tools::assist_vanagon_build and
meep_tools::nfs_mount.

The host-key-check must be set to false so that Bolt doesn't abort connecting
to Pooler hosts that identify with self signed certs (I believe?).  Setting
user to root is a convenience over specifying it; although the
test-pe-postgresql.rb script probably relies on it.

# test-pe-postgresql.rb

Used to assist with building and testing pe-postgresql packages from
puppet-enterprise-vanagon.

This script should be run from your puppet-enterprise-vanagon repo.

The following notes assuming /s -> $HOME/work/src/meep_tools to save some
space.

## create

Checks out a set of five test hosts (for each PE master platform) from
vmpooler; relies on vmfloaty installed, and that you have a token set to give
the hosts longevity.

```sh
/s/meep_tools/scripts/test-pe-postgresql.rb create
```

The currently created node hostnames are cached at ~/.test-pe-postgresql.json.
If the nodes still exist, nothing is created; otherwise new nodes will be
checked out.

## mount

Runs the meep_tools::nfs_mount plan for each of the nodes generated in create.

This attempts to add an /etc/exports entry allowing each of the created nodes
to mount $HOME/work/src as a local /$USER-src path. This is done so that
copying the packages is simplified, which is a first step for other scripts
that repackage a pe tarball and rerun an install on the vm.

In order for the export to be written, your local
~/.puppetlabs/bolt/inventory.yaml needs an entry for the external IP of your
workstation. (For a platform9 host, I haven't figured out how to find that from
within the host.)

So in my ~/.puppetlabs/bolt/inventory.yaml, for example, I have:

```
nodes:
  - name: 'localhost'
    vars:
      workstation_ip: '10.234.2.148'
```

## prep

In order to be able to test a PE install with the new packages, a PE tarball
needs to be stitched together with the new packages signed and inserted into it.

This happens on each vm test node, as the package signing/repo metadata
rebuilding commands are all platform specific.

The prep command grabs the latest build (you must specify pe_family, currently
2019.1 is waht we are interested in), unpacks it and runs
'puppet-enterprise-installer -p' (prep mode), which unpacks, sets up the
package repository locally, but does not install.

## build

The script will build all of the packages required for pe-postgresql in parallel.
You will need to either run the command while your current working directory is the
puppet-enterprise-vanagon folder, or specify where this folder exists with the 
--vanagon_path flag.

```sh
/s/meep_tools/scripts/test-pe-postgresql.rb build --version 11 --vanagon_path=<path_to_puppet-enterprise-vanagon>
```

## building pgrepack

pgrepack requires the -devel package to be available on the vmpooler host vanagon is using to build.
In order to test the pe-postgresql packages before they get promoted, you will need to
pry into the build process to pause it, install the packages, and then continue the build.

To do this, clone puppetlabs/vanagon.  Add a binding.pry statement [here](https://github.com/puppetlabs/vanagon/blob/master/lib/vanagon/driver.rb#L108). You will also need to add pry-byebug to the puppet-enterprise-vanagon Gemfile.

To run the build, from inside the puppet-enterprise-vanagon folder, do 
```sh
VANAGON_LOCATION=file://$HOME/path/to/vanagon/folder bundle exec build pe-postgresql11-pgrepack <platform>
```

When the pry statement is hit, run 
```
bolt plan run meep_tools::assist_vanagon_build postgres_version=11 output_dir=/path/to/puppet_enterprise_vanagon/output nodes=<node used for build>
```

Note that currently on Ubuntu 16.04, due to an issue with public keys, before running the bolt plan,
you will need to log into the vmpooler host, run apt-get update, and note the key it prints after "NO_PUBKEY".
Then do
```
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys <key>
```
Then continue with running the bolt plan.

# rerun-pe-install-with-pe-postgresql10-packages.sh

This script needs to be run from each vm. So, assuming you have vms with nfs
mounts set up by the test-pe-postgresql.rb tool (above), and that the node is
prepped (also above), you should be able to:

```sh
/$USER/meep_tools/script/rerun-pe-install-with-pe-postgresql10-packages.sh -v 10
```

/$HOME/work/src should include the meep_tools folder, a clone of the frankenbuilder
repo, and the puppet-enterprise-vanagon folder that contains the packages in the output
folder after running the build command (see above).

To begin the process of getting the packages copied in, signed, metadata
rebuilt, and launching puppet-enterprise-configure with the correct
puppet_enterprise::postgres_override_version flag to install the version of the
packages you are intersted in (pe-postgresql10 in my above example).

This script should be turned into a plan, but I haven't had a chance yet.

The packages could be uploaded or rsynced by another task, and the nfs mount
step could be dropped then as well.

If you need to test the packages alongside some puppet-enterprise-module
changes, the -m flag has not yet caught up to the shift to
puppet-enterprise-modules...so that won't work right now until I get a chance
to fix that.
