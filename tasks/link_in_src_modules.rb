#! /opt/puppetlabs/puppet/bin/ruby

require_relative '../lib/meep_tools/executor.rb'

MeepTools::Executor.run do |tool,params|
  modules = params['modules']
  link = params['modules']

  modules.each do |m|
    tool.link_module(m, link: link)
  end
end
