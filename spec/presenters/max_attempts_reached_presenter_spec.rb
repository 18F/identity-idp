require 'rails_helper'

RSpec.describe TwoFactorAuthCode::MaxAttemptsReachedPresenter do
  let(:type) { 'otp_requests' }
  let(:user) { instance_double(User) }
  let(:presenter) { described_class.new(type, user) }

  describe '#type' do
    subject { presenter.type }

    it { is_expected.to eq(type) }
  end

  describe '#user' do
    subject { presenter.user }

    it { is_expected.to eq(user) }
  end

  describe '#locked_reason' do
    subject(:locked_reason) { presenter.locked_reason }

    it 'returns locked reason' do
      expect(locked_reason).to eq(t('two_factor_authentication.max_otp_requests_reached'))
    end

    context 'with unsupported type' do
      let(:type) { :unsupported }

      it 'raises error' do
        expect { locked_reason }.to raise_error
      end
    end
  end
end
