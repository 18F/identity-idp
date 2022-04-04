require 'rails_helper'

describe TwoFactorAuthCode::MaxAttemptsReachedPresenter do
  let(:type) { 'otp_requests' }
  let(:decorated_user) { instance_double(UserDecorator) }
  let(:presenter) { described_class.new(type, decorated_user) }

  describe '#type' do
    subject { presenter.type }

    it { is_expected.to eq(type) }
  end

  describe '#decorated_user' do
    subject { presenter.decorated_user }

    it { is_expected.to eq(decorated_user) }
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
