require 'spec_helper'
require 'osc/open_stack_control'

# NOTE: These tests interact directly with slice and require that you have
# .fog set up with correct parameters and a good token (see README.md)
describe 'open_stack_control' do
  Fg = Fog::Compute::OpenStack

  let(:out) { StringIO.new }
  let(:argv) { [] }
  let(:beaker_hosts_arg) { ['--beaker-hosts-path', "#{fixtures_path}/beaker"] }
  let(:subject) { OSC::OpenStackControl.process(argv, out) }

  def run
    subject.run
    out.rewind
  end

  RSpec.shared_context('manage servers') do
    around(:each) do |example|
      begin
        instances = servers.map do |server_definition|
          attrs = case server_definition
          when Hash then server_definition
          else
            {
              'name'   => server_definition,
              'flavor' => 'g1.small',
              'image'  => 'centos_7_x86_64',
            }
          end
          subject.create_server(attrs)
        end
        example.run
      ensure
        instances.each { |i| i.destroy } if instances
      end
    end
  end

  RSpec.shared_context('manage a pod of servers') do
    around(:each) do |example|
      begin
        created = StringIO.new
        osc = OSC::OpenStackControl.process(['create', pod, *beaker_hosts_arg], created)
        osc.run

        example.run
      ensure
        deleted = StringIO.new
        osc = OSC::OpenStackControl.process(['drop', pod, *beaker_hosts_arg], deleted)
        osc.run
      end
    end
  end

  context '#lookup_flavor' do
    it do
      f = subject.lookup_flavor('g1.small')
      expect(f).to be_a(Fg::Flavor)
      expect(f.name).to eq('g1.small')
    end

    it 'raises an error when flavor does not exist' do
      expect { subject.lookup_flavor('doesnotexist') }.to(
        raise_error(OSC::UnknownServerAttribute, /Failed flavors lookup\. Could not find 'doesnotexist' in:/)
      )
    end
  end

  context '#lookup_image' do
    it do
      i = subject.lookup_image('centos_7_x86_64')
      expect(i).to be_a(Fg::Image)
      expect(i.name).to eq('centos_7_x86_64')
    end

    it 'raises an error when image does not exist' do
      expect { subject.lookup_image('doesnotexist') }.to(
        raise_error(OSC::UnknownServerAttribute, /Failed images lookup\. Could not find 'doesnotexist' in:/)
      )
    end
  end

  context '#lookup_security_group' do
    it do
      i = subject.lookup_security_group('default')
      expect(i).to be_a(Fg::SecurityGroup)
      expect(i.name).to eq('default')
    end
  end

  context '#create_server' do
    after(:each) do
      subject.drop_server('test1')
    end

    it do
      instance = subject.create_server({
        'name'   => 'test1',
        'flavor' => 'g1.small',
        'image'  => 'centos_7_x86_64',
      })
      expect(instance).to be_a(Fg::Server)
      expect(instance.name).to eq('test1')
    end
  end

  context '#drop_server' do

    context 'that does not exist' do
      it do
        expect(subject.drop_server('doesnotexist')).to eq(false)
      end
    end

    context 'that exists' do
      before(:each) do
        subject.create_server(
          'name'   => 'test1',
          'flavor' => 'g1.small',
          'image'  => 'centos_7_x86_64',
        )
      end

      it do
        expect(subject.drop_server('test1')).to eq(true)
        expect(subject.get_server('test1')).to be_nil
      end
    end
  end

  context '#get_server' do

    context 'that does not exist' do
      it { expect(subject.get_server('doesnotexist')).to be_nil }
    end

    context 'that exists' do
      include_context('manage servers')

      let(:servers) { [ 'test1' ] }

      it do
        instance = subject.get_server('test1')
        expect(instance).to(
          be_a(Fg::Server).and(have_attributes(:name => 'test1'))
        )
      end
    end
  end

  context '#server_list' do

    include_context('manage servers')

    let(:servers) do
      [ 'foo', 'bar' ]
    end

    it do
      expect(subject.server_list(nil)).to include(
        be_a(Fg::Server).and(have_attributes(:name => 'foo')),
        be_a(Fg::Server).and(have_attributes(:name => 'bar'))
      )
    end

    context 'of a pod' do
      let(:argv) { beaker_hosts_arg }

      include_context('manage a pod of servers')

      let(:pod) { 'test2' }

      it do
        expect(subject.server_list(pod)).to contain_exactly(
          be_a(Fg::Server).and(have_attributes(:name => 'centos2.rspec')),
          be_a(Fg::Server).and(have_attributes(:name => 'ubuntu2.rspec'))
        )
      end
    end
  end

  context 'create, list and drop a pod' do
    let(:pod) { 'test' }

    it do
      begin
        created = StringIO.new
        osc = OSC::OpenStackControl.process(['create', pod, *beaker_hosts_arg], created)
        osc.run
        created.rewind
        output = created.read
        expect(output).to match(/Created: centos.rspec/)
        expect(output).to match(/Created: ubuntu.rspec/)

        listed = nil
        10.times do |i|
          listed = StringIO.new
          osc = OSC::OpenStackControl.process(['list', pod, *beaker_hosts_arg], listed)
          osc.run
          listed.rewind
          break if listed.read == "centos.rspec\nubuntu.rspec\n"
        end
        listed.rewind
        expect(listed.read).to eq("centos.rspec\nubuntu.rspec\n")

      ensure
        deleted = StringIO.new
        osc = OSC::OpenStackControl.process(['drop', pod, *beaker_hosts_arg], deleted)
        osc.run
        deleted.rewind
        output = deleted.read
        expect(output).to match(/Dropped: centos.rspec/)
        expect(output).to match(/Dropped: ubuntu.rspec/)
      end
    end
  end

  context 'list all' do
    let(:argv) { ['list', *beaker_hosts_arg] }

    include_context('manage servers')

    let(:servers) do
      [ 'foo', 'bar' ]
    end

    it do
      run
      expect(out.read).to include('foo').and(include('bar'))
    end
  end

  context 'show host' do
    let(:argv) { ['show', 'foo'] }

    include_context('manage servers')

    let(:servers) do
      [ 'foo' ]
    end

    it do
      run
      expect(out.read).to match(/Fog::Compute::OpenStack::Server/)
    end

    context 'when host does not exist' do
      let(:argv) { ['show', 'doesnotexist'] }

      it do
        expect { subject.run }.to(
          raise_error(OSC::UnknownHost, /Failed to find a host named 'doesnotexist'/)
        )
      end
    end
  end
end
