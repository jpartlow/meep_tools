require 'pp'
require 'pry-byebug'
require 'rspec'

RSpec.configure do |c|
  # Disable deprecated rspec mocks 'should' syntax so that rspec-mocks doesn't add
  # :stub to BasicObject. Its presence causes an error with Bolt's ruby_smb library
  # which also expects to be able to create a :stub method on objects.
  c.mock_with :rspec do |mocks|
    mocks.syntax = :expect
  end
  c.mock_with :rspec
end
require 'puppetlabs_spec_helper/module_spec_helper'
require 'bolt_spec/plans'

require 'spec_helper_local' if File.file?(File.join(File.dirname(__FILE__), 'spec_helper_local.rb'))

$LOAD_PATH << File.expand_path(File.join(File.dirname(__FILE__),'..','lib'))
$LOAD_PATH << File.expand_path(File.join(File.dirname(__FILE__),'..','scripts'))

require 'shared/contexts'
require 'shared/matchers'

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

RSpec::Support::ObjectFormatter.default_instance.max_formatted_output_length = 999
