#! /usr/bin/ruby
require 'pp'
require 'optparse'

options = {}
parser = OptionParser.new do |opts|
  opts.banner = "Usage: rollback.rb [pe-host1 pe-host2] --name SNAPSHOT_NAME"
  
  opts.on("-n", "--name SNAPSHOT_NAME", "The snapshot name to rollback to (Required)") do |n|
    options[:name] = n
  end

  if options.empty?
  end
end

hosts = parser.parse!
snapshot_name = options[:name]

if snapshot_name.nil?
  puts parser
  exit
end

if hosts.empty?
  hosts = `vagrant hosts list`.split("\n")
  hosts.map! do |host|
    host.split(' ')[2] 
  end
end

running = `vboxmanage list runningvms`.split("\n")

running.map! do |r|
  md = r.match(/"[^_]+_([^_]+)_/)
  md[1]
end

rollback = hosts  & running
puts "Rolling back: #{rollback.pretty_inspect}  to: #{snapshot_name}"
print "Ok? (y/N) "
answer = STDIN.gets.chomp
exit unless answer == "y"

system("vagrant snap rollback #{rollback.join(' ')} --name=#{snapshot_name}")
rollback.each do |host|
  if system("pwd | grep -q -E 'el|centos'")
    system("vagrant ssh #{host} -c 'sudo service network restart'")
  end
end
