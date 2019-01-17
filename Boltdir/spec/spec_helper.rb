require 'rspec'
require 'rspec-puppet'
require 'bolt'
require 'bolt_spec/plans'
require 'pp'
require 'pry-byebug'

BOLTDIR = File.join(File.dirname(__FILE__),'..')

module BoltHelpers
  def boltdir
    BOLTDIR
  end

  # Overriding the default config() from BoltSpec::Plans
  def config
    @config ||= begin
      conf = Bolt::Config.new(Bolt::Boltdir.new(boltdir), {})
      conf.modulepath = [modulepath].flatten
      conf
    end
  end
end

RSpec.configure do |c|
  c.include(BoltSpec::Plans)
  c.include(BoltHelpers)
  c.before(:suite) { BoltSpec::Plans.init }
  c.module_path = ["#{BOLTDIR}/modules", "#{BOLTDIR}/site"]
end
