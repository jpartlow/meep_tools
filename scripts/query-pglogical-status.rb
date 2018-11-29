#! /opt/puppetlabs/puppet/bin/ruby

require 'pp'
require 'open3'
require 'pry-byebug'

databases=[
  'pe-activity',
  'pe-classifier',
  'pe-orchestrator',
  'pe-rbac',
]

databases.each do |d|
  command = %Q{su -s /bin/bash pe-postgres -c 'cd;/opt/puppetlabs/server/bin/psql #{d} -t -c "select pglogical.show_subscription_status()"'}
  out, err, status = Open3.capture3(command)
  stripped = out.strip[1..-2]
  subscriptions = stripped.scan(%r{((?:[^,]|"[^"]*")+),(?=(?:[^"]|"[^"]*")*$)}).flatten
  puts "#{d} #{subscriptions[0]}: #{subscriptions[1]}"
  puts status if !status.success?
end
