#! /opt/puppetlabs/puppet/bin/ruby

require_relative '../lib/meep_tools/executor.rb'

MeepTools::Executor.run do |tool,params|
  modules = params['modules']
  link = params['link']
  branch = params['branch']
  src_dir = params['src_dir']

  modules.each do |m|
    tool.link_module(m, branch, link: link, src_dir: src_dir )
  end
end
