require 'rspec'

RSpec.configure do |c|
  c.mock_with :rspec
end
require 'puppetlabs_spec_helper/module_spec_helper'
require 'bolt'
require 'bolt_spec/plans'
require 'pp'
require 'pry-byebug'

require 'spec_helper_local' if File.file?(File.join(File.dirname(__FILE__), 'spec_helper_local.rb'))

$LOAD_PATH << File.expand_path(File.join(File.dirname(__FILE__),'..','lib'))
$LOAD_PATH << File.expand_path(File.join(File.dirname(__FILE__),'..','scripts'))

module SpecHelpers
  def self.fixtures_path
    File.expand_path(File.join(File.dirname(__FILE__),'fixtures'))
  end

  def fixtures_path
    self.class.fixtures_path
  end
end

RSpec.configure do |c|
  c.include(SpecHelpers)
  c.include(BoltSpec::Plans)
  c.before(:suite) { BoltSpec::Plans.init }
  c.filter_run_excluding(bolt: true) unless ENV['GEM_BOLT']
end
