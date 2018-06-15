require 'spec_helper'
require 'osc/open_stack_control'

describe 'open_stack_control' do
  let(:out) { StringIO.new }
  let(:argv) { [] }
  let(:subject) { OSC::OpenStackControl.process(argv, out) }

  def run
    subject.run
    out.rewind
  end

  def expect_flag_to_match(matcher)
    expect(subject.exit_code).to eq(0)
    expect(subject).to be_a(OSC::Noop)
    out.rewind
    expect(out.read.chomp).to matcher
    expect { subject.run }.to raise_error(SystemExit)
  end

  context 'invalid options' do
    it do
      osc = OSC::OpenStackControl.process(['--foo'], out)
      expect(osc).to be_a(OSC::Noop)
      out.rewind
      expect(out.read).to match(/invalid option: --foo/)
    end
  end

  context 'no subcommand' do
    it { expect(subject.run).to eq(1) }

    it do
      run
      expect(out.read).to match(/Usage: oscontrol/)
    end

    it 'responds to a help option' do
      argv << '--help'
      expect_flag_to_match(match(/Usage: oscontrol/))
    end

    it 'prints version' do
      argv << '--version'
      expect_flag_to_match(eq(OSC::OpenStackControl::VERSION))
    end
  end

  context 'list' do
    context '--help' do
      let(:argv) { ['list', '--help'] }

      it 'responds to a help option' do
        argv << '--help'
        expect_flag_to_match(match(/Usage: oscontrol list/))
      end
    end
  end

  context 'create' do
    let(:argv) { ['create'] }

    context 'with no pod specified' do
      it do
        run
        expect(out.read).to match(/No hosts pod specified.*Usage: oscontrol/m)
      end
    end
  end

  context 'drop' do
  end

  context '#get_pod_hosts' do
    let(:argv) { ['--beaker-hosts-path', "#{fixtures_path}/beaker"] }
    let(:common_attrs) do
      {
        'security_group'   => ['default','sg0'],
        'floating_ip_pool' => 'ext-net-pdx1-opdx1',
        'ssh'              => {
          'keys' => ['~/.ssh/slice-jpartlow.pem'],
        },
        'flavor' => 'g1.small',
      }
    end
    let(:expected) do
      [
        {
          'name'   => 'centos.rspec',
          'image'  => 'centos_7_x86_64',
          'user'   => 'centos',
        }.merge(common_attrs),
        {
          'name'   => 'ubuntu.rspec',
          'image'  => 'ubuntu_16.04_x86_64',
          'user'   => 'ubuntu',
        }.merge(common_attrs),
      ]
    end

    it do
      hosts = subject.get_pod_hosts('test')

      expect(hosts.first).to match(expected[0])
      expect(hosts.last).to match(expected[1])
      expect(hosts).to match(expected)
    end

    it do
      expect { subject.get_pod_hosts('doesnotexist') }.to raise_error(
        OSC::NoHostsFile,
        %r|Could not find any beaker hosts files matching #{fixtures_path}/beaker/doesnotexist\.{hosts,yaml}|
      )
    end

    it do
      expect { subject.get_pod_hosts(nil) }.to raise_error(
        OSC::NoHostsFile,
        %r|Could not find.*#{fixtures_path}/beaker/\.{hosts,yaml}|
      )
    end
  end

  context '#openstack_floatingips' do
    let(:fips) { [] }

    before(:each) do
      expect(subject).to receive(:openstack_get_json).with('floating','ip','list')
        .and_return(fips)
    end

    it 'returns empty list if there are no floating ips' do
      expect(subject.openstack_floatingips).to eq([])
    end

    context 'with floating ips' do
      let(:fips_boilerplate) do
        {
          "Project" => "fb7cd1e6291c48f38fc6541168827012",
          "Fixed IP Address" => nil,
          "Port" => nil,
          "Floating Network" => "1c66e248-4fcb-405a-be75-821f85fc3ddb",
          "ID" => "fecde7b2-9f31-49e9-9b8f-0f1765be2821",
        }
      end
      let(:fips) do
        [
          fips_boilerplate.merge("Floating IP Address" => '10.32.160.34'),
          fips_boilerplate.merge("Floating IP Address" => '10.32.160.21'),
          fips_boilerplate.merge("Floating IP Address" => '10.32.157.125'),
          fips_boilerplate.merge("Floating IP Address" => '10.32.160.157'),
          fips_boilerplate.merge("Floating IP Address" => '10.32.160.20'),
          fips_boilerplate.merge("Floating IP Address" => '10.32.157.20'),
          fips_boilerplate.merge("Floating IP Address" => '10.32.160.201'),
          fips_boilerplate.merge("Floating IP Address" => '10.32.160.10'),
          fips_boilerplate.merge("Floating IP Address" => '10.32.160.156'),
          fips_boilerplate.merge("Floating IP Address" => '10.31.160.156'),
          fips_boilerplate.merge("Floating IP Address" => '10.32.160.12'),
        ]
      end

      it 'returns list of sorted ips' do
        expect(subject.openstack_floatingips).to eq([
          '10.32.160.201',
          '10.32.160.157',
          '10.32.160.156',
          '10.32.160.34',
          '10.32.160.21',
          '10.32.160.20',
          '10.32.160.12',
          '10.32.160.10',
          '10.32.157.125',
          '10.32.157.20',
          '10.31.160.156',
        ])
      end

      context 'with allocated ips' do
        let(:fips_allocated_boilerplate) do
          i = 0
          fips_boilerplate.merge(
            "Fixed IP Address" => "192.168.0.#{i += 1}",
            "Port" => "8b9f98a0-1b81-49b6-9367-73a609013a38"
          )
        end
        let(:fips) do
          [
            fips_boilerplate.merge("Floating IP Address" => '10.32.160.34'),
            fips_boilerplate.merge("Floating IP Address" => '10.32.160.21'),
            fips_allocated_boilerplate.merge("Floating IP Address" => '10.32.157.125'),
            fips_boilerplate.merge("Floating IP Address" => '10.32.160.157'),
            fips_allocated_boilerplate.merge("Floating IP Address" => '10.32.160.20'),
            fips_boilerplate.merge("Floating IP Address" => '10.32.157.20'),
            fips_boilerplate.merge("Floating IP Address" => '10.32.160.201'),
            fips_boilerplate.merge("Floating IP Address" => '10.32.160.10'),
            fips_allocated_boilerplate.merge("Floating IP Address" => '10.32.160.156'),
            fips_boilerplate.merge("Floating IP Address" => '10.31.160.156'),
            fips_boilerplate.merge("Floating IP Address" => '10.32.160.12'),
          ]
        end

        it 'only returns available ips' do
          expect(subject.openstack_floatingips).to eq([
            '10.32.160.201',
            '10.32.160.157',
            '10.32.160.34',
            '10.32.160.21',
            '10.32.160.12',
            '10.32.160.10',
            '10.32.157.20',
            '10.31.160.156',
          ])
        end
      end
    end
  end
end
