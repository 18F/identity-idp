require 'rails_helper'

describe TwoFactorAuthCode::MaxAttemptsReachedPresenter do
  let(:type) { 'otp_requests' }
  let(:decorated_user) { mock_decorated_user }
  let(:presenter) { described_class.new(type, decorated_user) }

  describe 'it uses the :locked failure state' do
    subject { presenter.state }

    it { is_expected.to eq(:locked) }
  end

  describe '#type' do
    subject { presenter.type }

    it { is_expected.to eq(type) }
  end

  describe '#decorated_user' do
    subject { presenter.decorated_user }

    it { is_expected.to eq(decorated_user) }
  end

  context 'methods are overriden' do
    %i[message title header description js].each do |method|
      describe "##{method}" do
        subject { presenter.send(method) }

        it { is_expected.to_not be_nil }
      end
    end
  end

  describe '#next_steps' do
    subject { presenter.next_steps }

    it 'includes `please_try_again` and `read_about_two_factor_authentication`' do
      expect(subject).to eq(
        [
          presenter.send(:please_try_again),
          presenter.send(:read_about_two_factor_authentication),
        ],
      )
    end
  end

  describe '#please_try_again' do
    subject { presenter.send(:please_try_again) }

    it 'includes time remaining' do
      expect(subject).to include('1000 years')
    end
  end

  def mock_decorated_user
    decorated_user = instance_double(UserDecorator)
    allow(decorated_user).to receive(:lockout_time_remaining_in_words).and_return('1000 years')
    allow(decorated_user).to receive(:lockout_time_remaining).and_return(10_000)
    decorated_user
  end
end
