require 'spec_helper'

require 'shared/test_executor'
require 'matchers/execute_with'

require 'test-pe-postgresql'

describe 'TestPostgresql' do

  def load_json_file(path)
    file = File.new(path)
    JSON.load(file)
  end

  after(:each) do
    FileUtils.remove_entry_secure(tmpdir)
  end

  let(:tmpdir) { Dir.mktmpdir('test-pe-postgresql') }
  let(:test_hosts_cache_path) { File.join(SpecHelpers.fixtures_path, 'test-pe-postgresql', 'test-pe-postgresql.json') }
  let(:cache) { load_json_file(test_hosts_cache_path) }

  it { expect(TestPostgresql.new).to be_kind_of(TestPostgresql) }

  context 'reading and writing config' do
    let(:tmp_hosts_cache_path) { "#{tmpdir}/test.json" }

    before(:each) do
      allow(TestPostgresql).to receive(:hosts_cache).and_return(tmp_hosts_cache_path)
    end

    it do
      expect(TestPostgresql.read_hosts_cache(test_hosts_cache_path)).to eq(cache)
    end

    it 'round trips configuration' do
      test_cache = { 'foo'=>'bar'}
      tester = TestPostgresql.new
      tester.hosts = test_cache
      expect(tester.write_hosts_cache(tmp_hosts_cache_path)).to eq(true)
      expect(TestPostgresql.read_hosts_cache(tmp_hosts_cache_path)).to eq(test_cache)
    end

    it 'handles empty paths' do
      expect(TestPostgresql.read_hosts_cache(nil)).to eq({})
      expect(TestPostgresql.read_hosts_cache('')).to eq({})
    end

    context 'when modified' do
      RSpec.shared_examples('writes modified configuration') do
        it do
          tester = TestPostgresql.new

          tester.hosts['el-6-x86_64'] = 'foo.net'
          tester.hosts['el-7-x86_64'] = 'foo7.net'

          expect(tester.write_hosts_cache(tmp_hosts_cache_path)).to eq(true)
          expect(TestPostgresql.read_hosts_cache(tmp_hosts_cache_path)).to match_array(
            'el-6-x86_64' => 'foo.net',
            'el-7-x86_64' => 'foo7.net'
          )
        end
      end

      context 'from an empty config' do
        let(:test_cache) { {} }

        include_examples('writes modified configuration')
      end
    end
  end

  context 'creating hosts' do
    let(:tmp_hosts_cache_path) { "#{tmpdir}/test.json" }

    let(:platforms) do
      [
        'el-6-x86_64',
        'ubuntu-18.04-amd64',
        'sles-12-x86_64',
      ]
    end
    let(:tester) do
      TestPostgresql.new([], { "platforms" => platforms })
    end

    it { expect(tester.translate_platform_for_vmfloaty('el-6-x86_64')).to eq('centos-6-x86_64') }
    it { expect(tester.translate_platform_for_vmfloaty('ubuntu-18.04-amd64')).to eq('ubuntu-1804-x86_64') }
    it { expect(tester.translate_platform_for_vmfloaty('ubuntu-1804-amd64')).to eq('ubuntu-1804-x86_64') }
    it { expect(tester.translate_platform_for_vmfloaty('ubuntu-18.04-x86_64')).to eq('ubuntu-1804-x86_64') }
    it { expect(tester.translate_platform_for_vmfloaty('sles-12-x86_64')).to eq('sles-12-x86_64') }

    it do
      allow(TestPostgresql).to receive(:hosts_cache_file).and_return(tmp_hosts_cache_path)
      TestExecutor.add_response(/floaty get/, '- foo.delivery.puppetlabs.net (platform)')
      expect(tester).to(
        execute
          .and_call('create_hosts')
          .and_output([
            /Verify or create hosts/,
          ])
          .and_generate_commands([
            /floaty get centos-6-x86_64/,
            /floaty get ubuntu-1804-x86_64/,
            /floaty get sles-12-x86_64/,
          ])
      )
      expect(tester.hosts).to match({
        'el-6-x86_64' => /^\w+\.delivery\.puppetlabs\.net$/,
        'ubuntu-18.04-amd64' => /^\w+\.delivery\.puppetlabs\.net$/,
        'sles-12-x86_64' => /^\w+\.delivery\.puppetlabs\.net$/,
      })
    end
  end

  context 'execute_with' do
  end

  context 'initializing hosts' do
  end

  context 'building packages' do
    around(:each) do |example|
      begin
        FileUtils.mkdir('/tmp/puppet-enterprise-vanagon')
        example.run
      ensure
        FileUtils.rmdir('/tmp/puppet-enterprise-vanagon')
      end
    end

    it 'builds all the base pe-postgresql<version>* packages' do
      expect(TestPostgresql).to(
        execute
          .and_invoke_with('build --version=96 --vanagon-path=/tmp/puppet-enterprise-vanagon')
          .and_generate_commands([
            /build pe-postgresql96 el-7-x86_64/,
            /build pe-postgresql96 el-6-x86_64/,
            /build pe-postgresql96 ubuntu-16.04-amd64/,
            /build pe-postgresql96 ubuntu-18.04-amd64/,
            /build pe-postgresql96 sles-12-x86_64/,
            /build pe-postgresql96-server sles-12-x86_64/,
            # ...
            /build pe-postgresql96-contrib sles-12-x86_64/,
            # ...
            /build pe-postgresql96-devel sles-12-x86_64/,
            # ...
          ])
      )
    end

    it 'builds the pe-postgresql-common package' do
      expect(TestPostgresql).to(
        execute
          .and_invoke_with('build_common --vanagon-path=/tmp/puppet-enterprise-vanagon')
          .and_generate_commands([
            /build pe-postgresql-common el-7-x86_64/,
            /build pe-postgresql-common el-6-x86_64/,
            /build pe-postgresql-common ubuntu-16.04-amd64/,
            /build pe-postgresql-common ubuntu-18.04-amd64/,
            /build pe-postgresql-common sles-12-x86_64/,
          ])
      )
    end

    it 'builds the pe-postgresql<version>-<extension> packages' do
      expect(TestPostgresql).to(
        execute
          .and_invoke_with('build_extensions --version=96 --vanagon-path=/tmp/puppet-enterprise-vanagon')
          .and_generate_commands([
            /build pe-postgresql96-pglogical el-7-x86_64/,
            /build pe-postgresql96-pglogical el-6-x86_64/,
            /build pe-postgresql96-pglogical ubuntu-16.04-amd64/,
            /build pe-postgresql96-pglogical ubuntu-18.04-amd64/,
            /build pe-postgresql96-pglogical sles-12-x86_64/,
            /build pe-postgresql96-pgrepack sles-12-x86_64/,
            # ...
          ])
      )
    end
  end

  context 'running tests on hosts' do
  end
end
