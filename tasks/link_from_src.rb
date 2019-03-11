#!/opt/puppetlabs/puppet/bin/ruby

require 'json'
require 'open3'

params = JSON.parse(STDIN.read)
require_relative File.join(params['_installdir'], 'meep_tools/lib/meep_tools/task_runner.rb')
require_relative File.join(params['_installdir'], 'meep_tools/lib/meep_tools/link.rb')

source_dir = params['source_dir']
target_dir = params['target_dir']

link_directory(source_dir, target_dir)

exit 0
