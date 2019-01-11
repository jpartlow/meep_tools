require 'rspec'
require 'pp'
require 'pry-byebug'

$LOAD_PATH << File.expand_path(File.join(File.dirname(__FILE__),'..','lib'))
$LOAD_PATH << File.expand_path(File.join(File.dirname(__FILE__),'..','scripts'))

module SpecHelpers
  def fixtures_path
    File.expand_path(File.join(File.dirname(__FILE__),'fixtures'))
  end
end

RSpec.configure do |c|
  c.include(SpecHelpers)
end
