require 'spec_helper'

describe 'meep_tools::ubuntu_codename' do
  it { is_expected.to run.with_params('18.04').and_return('bionic') }
  it { is_expected.to run.with_params('16.04').and_return('xenial') }
  it { is_expected.to run.with_params('20.04').and_raise_error(/Unknown Ubuntu os release codename for '20.04'/) }
end
