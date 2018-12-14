#! /opt/puppetlabs/puppet/bin/ruby
require 'pp'
require 'open3'

PUPPET_MODULES_PATH     = "/opt/puppetlabs/puppet/modules"
ENTERPRISE_MODULES_PATH = "/opt/puppetlabs/server/data/environments/enterprise/modules"

flags   = []
modules = []
ARGV.each do |o|
  case o
  when /^-/ then flags << o
  else modules << o
  end
end

def usage(error)
  puts "!! #{error}"
  puts
  puts "link-in-src-modules.rb [options] [modules]"
  puts
  puts " options:"
  puts "   -p : link modules into #{PUPPET_MODULES_PATH}"
  puts "   -e : link modules into #{ENTERPRISE_MODULES_PATH}"
  puts "   -a : link into both"
  puts
  puts " modules:"
  puts "   must be present in /jpartlow-src/pe-modules"
  puts
  puts " existing module will be moved into /root"
  exit 1
end

puppet_modules = false
enterprise_modules = false
flags.each do |f|
  case f
  when '-p' then puppet_modules = true
  when '-e' then enterprise_modules = true
  when '-a' then
    puppet_modules = true
    enterprise_modules = true
  else usage("Unknown option #{f}")
  end
end

puppet_modules = true if !puppet_modules && !enterprise_modules

available_modules = Dir.glob('/jpartlow-src/pe-modules/*').map do |m|
  m.split('/').last.gsub(/^puppetlabs-/,'')
end

found_modules = modules & available_modules
if found_modules.empty? || found_modules != modules
  usage("Some modules not present. Given: #{modules}\nAvailable modules:\n#{available_modules.pretty_inspect}")
end

def run(command)
  puts("#{command}")
  output, status = Open3.capture2e(command)
  puts output
  exit(1) unless status.success?
end

def link_module(name, path, type)
  puts "--> Linking #{name} into #{path}"
  current_module = "#{path}/#{name}"
  if !File.symlink?(current_module)
    backup = "/root/#{type}-#{name}"
    if !File.exist?(backup)
      run("mv -T #{current_module} #{backup}")
    else
      run("rm -rf #{current_module}")
    end
    run("ln -s /jpartlow-src/pe-modules/puppetlabs-#{name} #{current_module}")
  else
    puts " * link already set"
  end
end

if puppet_modules
  found_modules.each do |m|
    link_module(m, PUPPET_MODULES_PATH, 'base')
  end
end

if enterprise_modules
  found_modules.each do |m|
    link_module(m, ENTERPRISE_MODULES_PATH, 'enterprise')
  end
end
