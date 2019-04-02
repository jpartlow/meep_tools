require 'spec_helper'

describe 'meep_tools::get_vanagon_output_vars' do
  let(:osfacts) do
    {
      'family'  => osfamily,
      'release' => osrelease,
    }
  end

  context 'errors' do
    let(:osfamily) { 'MacOS' }
    let(:osrelease) { {} }

    it do
      is_expected.to run.with_params(osfacts).and_raise_error(/Unknown os family 'MacOS'/)
    end
  end

  context 'RedHat' do
    let(:osfamily) { 'RedHat' }
    let(:osrelease) do
      {
        'major' => '7',
        'full'  => '7.2',
      }
    end
  
    it do
      is_expected.to run.with_params(osfacts).and_return({
        'package_dir' => 'el/7/products/x86_64',
        'ext'         => 'rpm',
        'sep'         => '-',
        'platform'    => '.pe.el7.x86_64',
        'provider'    => 'rpm',
      })
    end
  end

  context 'Debian' do
    let(:osfamily) { 'Debian' }
    let(:osrelease) do
      {
        'major' => '18',
        'full'  => '18.04',
      }
    end
  
    it do
      is_expected.to run.with_params(osfacts).and_return({
        'package_dir' => 'deb/bionic',
        'ext'         => 'deb',
        'sep'         => '_',
        'platform'    => 'bionic_amd64',
        'provider'    => 'dpkg',
      })
    end

    context 'no codename' do
      let(:osrelease) do
        {
          'major' => '19',
          'full'  => '19.10',
        }
      end

      it do
        is_expected.to run.with_params(osfacts).and_raise_error(/Unknown Ubuntu os release codename for '19\.10'/)
      end
    end
  end

  context 'Sles' do
    let(:osfamily) { 'SLES' }
    let(:osrelease) do
      {
        'major' => '12',
        'full'  => '12.1',
      }
    end
  
    it do
      is_expected.to run.with_params(osfacts).and_return({
        'package_dir' => 'sles/12/products/x86_64',
        'ext'         => 'rpm',
        'sep'         => '-',
        'platform'    => '.pe.sles12.x86_64',
        'provider'    => 'rpm',
      })
    end
  end
end
