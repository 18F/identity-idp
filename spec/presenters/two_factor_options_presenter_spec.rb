require 'rails_helper'

RSpec.describe TwoFactorOptionsPresenter do
  include Rails.application.routes.url_helpers
  include RequestHelper

  let(:user) { build(:user) }
  let(:user_agent) do
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_6) AppleWebKit/537.36 \
(KHTML, like Gecko) Chrome/78.0.3904.87 Safari/537.36'
  end
  let(:after_mfa_setup_path) { account_path }
  let(:show_skip_additional_mfa_link) { true }

  let(:presenter) do
    described_class.new(user:, user_agent:, after_mfa_setup_path:, show_skip_additional_mfa_link:)
  end

  describe '#two_factor_enabled?' do
    it 'delegates to mfa_policy' do
      expect(presenter).to delegate_method(:two_factor_enabled?).to(:mfa_policy)
    end
  end

  describe '#options' do
    it 'supplies all the options for a user' do
      expect(presenter.options.map(&:class)).to eq [
        TwoFactorAuthentication::SetUpWebauthnPlatformSelectionPresenter,
        TwoFactorAuthentication::SetUpAuthAppSelectionPresenter,
        TwoFactorAuthentication::PhoneSelectionPresenter,
        TwoFactorAuthentication::SetUpBackupCodeSelectionPresenter,
        TwoFactorAuthentication::SetUpWebauthnSelectionPresenter,
        TwoFactorAuthentication::PivCacSelectionPresenter,
      ]
    end

    context 'when a phishing-resistant only SP is being used' do
      let(:presenter) do
        described_class.new(
          user_agent: user_agent, user: user_with_2fa,
          phishing_resistant_required: true
        )
      end

      it 'only displays phishing-resistant MFA methods' do
        expect(presenter.options.map(&:class)).to eq [
          TwoFactorAuthentication::SetUpWebauthnPlatformSelectionPresenter,
          TwoFactorAuthentication::SetUpWebauthnSelectionPresenter,
          TwoFactorAuthentication::PivCacSelectionPresenter,
        ]
      end
    end

    context 'when hide_phone_mfa_signup is enabled' do
      before do
        allow(IdentityConfig.store).to receive(:hide_phone_mfa_signup).and_return(true)
      end

      it 'supplies all the options except phone' do
        expect(presenter.options.map(&:class)).to eq [
          TwoFactorAuthentication::SetUpAuthAppSelectionPresenter,
          TwoFactorAuthentication::SetUpBackupCodeSelectionPresenter,
          TwoFactorAuthentication::SetUpWebauthnSelectionPresenter,
          TwoFactorAuthentication::PivCacSelectionPresenter,
        ]
      end
    end
    context 'when platform_auth_set_up_enabled is enabled' do
      before do
        allow(IdentityConfig.store).to receive(:platform_auth_set_up_enabled).
          and_return(true)
      end

      it 'supplies all the options except webauthn' do
        expect(presenter.options.map(&:class)).to eq [
          TwoFactorAuthentication::SetUpWebauthnPlatformSelectionPresenter,
          TwoFactorAuthentication::SetUpAuthAppSelectionPresenter,
          TwoFactorAuthentication::PhoneSelectionPresenter,
          TwoFactorAuthentication::SetUpBackupCodeSelectionPresenter,
          TwoFactorAuthentication::SetUpWebauthnSelectionPresenter,
          TwoFactorAuthentication::PivCacSelectionPresenter,
        ]
      end
    end
  end

  describe '#skip_path' do
    subject(:skip_path) { presenter.skip_path }
    it { expect(skip_path).to be_nil }

    context 'with mfa configured' do
      let(:user) { build(:user, :with_phone) }

      it { expect(skip_path).to eq(after_mfa_setup_path) }

      context 'with skip link hidden' do
        let(:show_skip_additional_mfa_link) { false }

        it { expect(skip_path).to be_nil }
      end
    end
  end

  describe '#skip_label' do
    subject(:skip_label) { presenter.skip_label }

    it 'is "Skip"' do
      expect(skip_label).to eq(t('mfa.skip'))
    end

    context 'user has dismissed second mfa reminder' do
      let(:user) { build(:user, second_mfa_reminder_dismissed_at: Time.zone.now) }

      it 'is "Cancel"' do
        expect(skip_label).to eq(t('links.cancel'))
      end
    end
  end

  describe '#show_skip_additional_mfa_link?' do
    it 'returns true' do
      expect(presenter.show_skip_additional_mfa_link?).to eq(true)
    end

    context 'when show_skip_additional_mfa_link is false' do
      let(:show_skip_additional_mfa_link) { false }
      let(:presenter) do
        described_class.new(
          user_agent: user_agent,
          show_skip_additional_mfa_link: show_skip_additional_mfa_link,
        )
      end

      it 'returns false' do
        expect(presenter.show_skip_additional_mfa_link?).to eq(false)
      end
    end
  end

  describe '#show_cancel_return_to_sp?' do
    context 'phishing resistant required to add additonal mfa' do
      let(:presenter) do
        described_class.new(
          user_agent: user_agent,
          user: user_with_2fa,
          phishing_resistant_required: true,
        )
      end

      it 'returns true' do
        expect(presenter.show_cancel_return_to_sp?).to eq(true)
      end
    end
  end
end
