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

  context '#link_directory' do
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

  context '#remote_src_dir' do
    around(:each) do |example|
      begin
        user = ENV['USER']
        ENV['USER'] = 'test'
        example.run
      ensure
        ENV['USER'] = user
      end
    end

    it { expect(tester.remote_src_dir).to eq("/test-src") }
  end

  RSpec.shared_context('test-src modules') do
    let(:remote_src_fixture_dir) { "#{SpecHelpers.fixtures_path}/test-src" }

    around(:each) do |example|
      begin
        module_dirs.each { |d| FileUtils.mkdir_p("#{remote_src_fixture_dir}/#{d}") }
        example.run
      ensure
        FileUtils.remove_entry_secure(remote_src_fixture_dir) if File.exist?(remote_src_fixture_dir)
      end
    end
  end

  context '#available_modules' do
    include_context('test-src modules')

    context 'when no modules' do
      let(:module_dirs) { [] }
      it { expect(tester.available_modules(remote_src_fixture_dir)).to match_array([]) }
    end

    context 'when puppet-enterprise-modules' do
      let(:module_dirs) do
        [
          'puppet-enterprise-modules/modules/puppet_enterprise',
          'puppet-enterprise-modules/modules/pe_install',
          'puppet-enterprise-modules/modules/pe_manager',
        ]
      end

      it do
        expect(tester.available_modules(remote_src_fixture_dir)).to match({
          'puppet_enterprise' => "#{remote_src_fixture_dir}/puppet-enterprise-modules/modules/puppet_enterprise",
          'pe_install' => "#{remote_src_fixture_dir}/puppet-enterprise-modules/modules/pe_install",
          'pe_manager' => "#{remote_src_fixture_dir}/puppet-enterprise-modules/modules/pe_manager",
        })
      end
    end

    context 'when pe-modules' do
      let(:module_dirs) do
        [
          'pe-modules/puppetlabs-pe_r10k',
          'pe-modules/puppetlabs-pe_support_script',
        ]
      end

      it do
        expect(tester.available_modules(remote_src_fixture_dir)).to match({
          'pe_r10k' => "#{remote_src_fixture_dir}/pe-modules/puppetlabs-pe_r10k",
          'pe_support_script' => "#{remote_src_fixture_dir}/pe-modules/puppetlabs-pe_support_script",
        })
      end
    end

    context 'when both' do
      let(:module_dirs) do
        [
          'puppet-enterprise-modules/modules/puppet_enterprise',
          'puppet-enterprise-modules/modules/pe_install',
          'puppet-enterprise-modules/modules/pe_manager',
          'pe-modules/puppetlabs-pe_r10k',
          'pe-modules/puppetlabs-pe_support_script',
        ]
      end

      it do
        expect(tester.available_modules(remote_src_fixture_dir)).to match({
          'puppet_enterprise' => "#{remote_src_fixture_dir}/puppet-enterprise-modules/modules/puppet_enterprise",
          'pe_install' => "#{remote_src_fixture_dir}/puppet-enterprise-modules/modules/pe_install",
          'pe_manager' => "#{remote_src_fixture_dir}/puppet-enterprise-modules/modules/pe_manager",
          'pe_r10k' => "#{remote_src_fixture_dir}/pe-modules/puppetlabs-pe_r10k",
          'pe_support_script' => "#{remote_src_fixture_dir}/pe-modules/puppetlabs-pe_support_script",
        })
      end
    end
  end

  context '#link_module' do
    it do
      expect { tester.link_module('puppet_enterprise') }.to raise_error(RuntimeError, /Module puppet_enterprise not present\. Available modules:\n\[\]/)
    end

    context 'with modules' do
      include_context('test-src modules')

      let(:module_dirs) do
        [
          'puppet-enterprise-modules/modules/puppet_enterprise',
          'puppet-enterprise-modules/modules/pe_install',
          'puppet-enterprise-modules/modules/pe_manager',
        ]
      end

      it do
        expect { tester.link_module('foo', remote_src_fixture_dir) }.to raise_error(RuntimeError, /Module foo not present\. Available modules:\n\[(?:"(?:puppet_enterprise|pe_install|pe_manager)"(?:, )?){3}\]/)
      end

      it do
        expect { tester.link_module('puppet_enterprise', remote_src_fixture_dir) }.to output(<<-EOM).to_stdout
--> Replacing /opt/puppetlabs/puppet/modules/puppet_enterprise with a link to /home/jpartlow/work/src/meep_tools/spec/fixtures/test-src/puppet-enterprise-modules/modules/puppet_enterprise
--> Replacing /opt/puppetlabs/server/data/environments/enterprise/modules/puppet_enterprise with a link to /home/jpartlow/work/src/meep_tools/spec/fixtures/test-src/puppet-enterprise-modules/modules/puppet_enterprise
        EOM
        expect(runner.commands).to match([
          match('mkdir -p /root/_meep_tools_backups/opt/puppetlabs/puppet/modules'),
          match('mv -T /opt/puppetlabs/puppet/modules/puppet_enterprise /root/_meep_tools_backups/opt/puppetlabs/puppet/modules/puppet_enterprise'),
          match('ln -s /home/jpartlow/work/src/meep_tools/spec/fixtures/test-src/puppet-enterprise-modules/modules/puppet_enterprise /opt/puppetlabs/puppet/modules/puppet_enterprise'),
          match('mkdir -p /root/_meep_tools_backups/opt/puppetlabs/server/data/environments/enterprise/modules'),
          match('mv -T /opt/puppetlabs/server/data/environments/enterprise/modules/puppet_enterprise /root/_meep_tools_backups/opt/puppetlabs/server/data/environments/enterprise/modules/puppet_enterprise'),
          match('ln -s /home/jpartlow/work/src/meep_tools/spec/fixtures/test-src/puppet-enterprise-modules/modules/puppet_enterprise /opt/puppetlabs/server/data/environments/enterprise/modules/puppet_enterprise'),
        ])
      end
    end
  end
end
