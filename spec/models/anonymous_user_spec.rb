require 'rails_helper'

RSpec.describe AnonymousUser do
  describe 'Methods' do
    it { is_expected.to respond_to(:phone_configurations) }
    it { is_expected.to respond_to(:uuid) }
    it { is_expected.to respond_to(:phone) }
    it { is_expected.to respond_to(:email) }
    it { is_expected.to respond_to(:second_factor_locked_at) }
  end

  describe '#phone_configurations' do
    subject { AnonymousUser.new.phone_configurations }

    it { is_expected.to eq [] }
  end
end
