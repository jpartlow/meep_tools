require 'spec_helper'
require 'meep_tools/symlinker'
require 'meep_tools/command_runner'

class SymlinkerTester
  attr_accessor :runner

  def initialize(runner)
    self.runner = runner
  end

  def run(*command)
    runner.run(*command)
  end

  include MeepTools::Symlinker
end

describe 'meep_tools/symlinker' do
  let(:runner) { MeepTools::TestRunner.new }
  let(:tester) { SymlinkerTester.new(runner) }

  context 'target is not yet symlinked' do
    context 'backup does not exist' do
      it 'moves the target to a backup and replaces with a symlink' do
        expect { tester.link_directory('/a/source', '/some/target') }.to output("--> Replacing /some/target with a link to /a/source\n").to_stdout
        expect(runner.commands).to match([
          'mkdir -p /root/_meep_tools_backups/some',  
          'mv -T /some/target /root/_meep_tools_backups/some/target',
          'ln -s /a/source /some/target',
        ])
      end
    end

    context 'backup exists' do
      it 'removes the target and replaces with a symlink' do
        expect(File).to receive(:exist?).with('/root/_meep_tools_backups/some/target').and_return(true)

        expect { tester.link_directory('/a/source', '/some/target') }.to output("--> Replacing /some/target with a link to /a/source\n").to_stdout
        expect(runner.commands).to match([
          'rm -rf /some/target',
          'ln -s /a/source /some/target',
        ])
      end
    end
  end

  context 'target is already a symlink' do
    it 'does nothing' do
      expect(File).to receive(:symlink?).with('/some/target').and_return(true)

      expect { tester.link_directory('/a/source', '/some/target') }.to output("--> Replacing /some/target with a link to /a/source\n * link already set\n").to_stdout
      expect(runner.commands).to be_empty
    end
  end
end
