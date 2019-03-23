require 'spec_helper'
require 'meep_tools/executor'

describe 'meep_tools/executor' do
  it 'returns what it executes' do
    executor = MeepTools::Executor.new(MeepTools::TestRunner.new, {})
    expect(executor.execute { 5 }).to eq(5)
  end

  it 'passes params' do
    executor = MeepTools::Executor.new(MeepTools::TestRunner.new, {'arg' => 1})
    expect(executor.execute { |tool,params| params['arg'] }).to eq(1)
  end

  context 'self.run' do
    let(:input) { StringIO.new('{ "arg": 2 }') }

    it 'parses stdin and executes the passed block' do
      expect(MeepTools::Executor.run(input) { |tool,params| params['arg'] }).to eq(2)
    end
  end

  context 'with TestRunner' do
    let(:params) { '{ "_testing": true }' }
    let(:input) { StringIO.new(params) }

    it do
      MeepTools::Executor.run(input) do |tool, params|
        tool.run('echo', 'hi')
      end
      commands = MeepTools::TestRunner.fetch(params)
      expect(commands).to eq(['echo hi'])
    end
  end
end
