#!/opt/puppetlabs/puppet/bin/ruby

require 'json'
require 'open3'

params = JSON.parse(STDIN.read)

packages = params['packages']

osfamily = `facter os.family`.chomp
osversion = `facter os.release.full`.chomp

command = case osfamily
when 'Debian'
  ['dpkg', '-L']
else
  ['rpm', '-ql']
end

files = {}
packages.each do |p|
  file_list, _s = Open3.capture2(*command, p)
  files[p] = file_list.split("\n").sort
end

puts JSON.dump({ "platform" => "#{osfamily}-#{osversion}", "files" => files })
exit 0
