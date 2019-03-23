require 'spec_helper'
require 'meep_tools/command_runner'

describe 'meep_tools/command_runner' do
  let(:tester) { MeepTools::CommandRunner.new }

  it 'previews what it is going to run' do
    expect { tester.run('echo hi') }.to output(/^echo hi$/).to_stdout
  end

  it 'prints output of what it ran' do
    expect { tester.run('echo hi') }.to output(/^hi$/).to_stdout
  end

  it 'returns status of command' do
    expect do
      expect(tester.run('true')).to be_an_instance_of(Process::Status).and(
        have_attributes(:exitstatus => 0)
      )
    end.to output(/^true$/).to_stdout
  end

  it 'exits 1 if command is unsuccessful' do
    expect { tester.run('false') }.to output(/^false$/).to_stdout.and(
      raise_error(SystemExit) do |e|
        expect(e.status).to eq(1)
      end
    ) 
  end 
end

describe 'meep_tools/test_runner' do
  let(:tester) { MeepTools::TestRunner.new }

  it 'logs command' do
    expect(tester.run('foo', 'bar')).to be_kind_of(Process::Status).and(
      have_attributes(:exitstatus => 0)
    )
    expect(tester.commands).to eq(['foo bar'])
  end

  context 'self.create' do
    let(:params) { '{ "arg": 1 }' }

    it 'keeps a log of commands in the class' do
      tester = MeepTools::TestRunner.create(params)
      expect(tester.run('foo', 'bar')).to be
      expect(MeepTools::TestRunner.fetch(params)).to eq(['foo bar'])
    end
  end
end
