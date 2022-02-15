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
    %i[title header description js].each do |method|
      describe "##{method}" do
        subject { presenter.send(method) }

        it { is_expected.to_not be_nil }
      end
    end
  end

  describe '#description' do
    subject(:description) { presenter.description }

    it 'includes failure type and time remaining' do
      expect(subject).to eq(
        [
          presenter.locked_reason,
          presenter.please_try_again,
        ],
      )
    end
  end

  describe '#troubleshooting_options' do
    subject { presenter.troubleshooting_options }

    it 'includes links to read more and get help' do
      expect(subject).to eq(
        [
          presenter.read_about_two_factor_authentication,
          presenter.contact_support,
        ],
      )
    end
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

  describe '#please_try_again' do
    subject { presenter.send(:please_try_again) }

    it 'includes time remaining' do
      expect(subject).to include('1000 years')
    end
  end

  describe '#read_about_two_factor_authentication' do
    subject(:link) { presenter.read_about_two_factor_authentication }

    it 'includes troubleshooting option link details' do
      expect(link).to match(
        text: kind_of(String),
        url: kind_of(String),
        new_tab: true,
      )
    end
  end

  describe '#contact_support' do
    subject(:link) { presenter.contact_support }

    it 'includes troubleshooting option link details' do
      expect(link).to match(
        text: kind_of(String),
        url: kind_of(String),
        new_tab: true,
      )
    end
  end

  def mock_decorated_user
    decorated_user = instance_double(UserDecorator)
    allow(decorated_user).to receive(:lockout_time_remaining_in_words).and_return('1000 years')
    allow(decorated_user).to receive(:lockout_time_remaining).and_return(10_000)
    decorated_user
  end
end
