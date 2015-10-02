#! /usr/bin/env ruby
require 'pp'

vboxes = `vboxmanage list vms`.split("\n")
vboxes.map! do |v|
  array = v.split(' ')
  [array[0].gsub(/^"|"$/, ''), array[1].gsub(/^{|}$/, '')]
end

vagrant_ids = `find -type d -name .vagrant | find -name id`.split("\n")
vagrant_configs = vagrant_ids.inject({}) do |hash,id_file|
  hash[`cat #{id_file}`] = id_file
  hash
end

vboxes.each do |dir,uuid|
  path = "/home/jpartlow/VirtualBox\ VMs/#{dir}"
  vagrant_config = vagrant_configs[uuid]
  if !Dir.exists?(path)
    puts "* No virtualbox folder found at #{path} for #{uuid}"
  end

  if vagrant_config.nil?
    puts "! No vagrant configuration found for this #{path} for #{uuid}" 
  else
    puts "Found #{vagrant_config} for #{uuid} matching #{path}" 
  end 
end
