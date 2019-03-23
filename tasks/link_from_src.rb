#!/opt/puppetlabs/puppet/bin/ruby

require_relative '../lib/meep_tools/executor.rb'

MeepTools::Executor.run do |tool,params|
  source_dir = params['source_dir']
  target_dir = params['target_dir']

  tool.link_directory(source_dir, target_dir)
end
