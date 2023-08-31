require 'rails_helper'

RSpec.describe TwoFactorOptionsPresenter do
  include Rails.application.routes.url_helpers
  include RequestHelper

  let(:user_agent) do
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_6) AppleWebKit/537.36 \
(KHTML, like Gecko) Chrome/78.0.3904.87 Safari/537.36'
  end

  let(:presenter) do
    described_class.new(user_agent: user_agent)
  end

  before do
    allow(IdentityConfig.store).to receive(:platform_auth_set_up_enabled).
      and_return(false)
  end

  describe '#options' do
    it 'supplies all the options for a user' do
      expect(presenter.options.map(&:class)).to eq [
        TwoFactorAuthentication::AuthAppSelectionPresenter,
        TwoFactorAuthentication::PhoneSelectionPresenter,
        TwoFactorAuthentication::BackupCodeSelectionPresenter,
        TwoFactorAuthentication::WebauthnSelectionPresenter,
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
          TwoFactorAuthentication::WebauthnSelectionPresenter,
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
          TwoFactorAuthentication::AuthAppSelectionPresenter,
          TwoFactorAuthentication::BackupCodeSelectionPresenter,
          TwoFactorAuthentication::WebauthnSelectionPresenter,
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
          TwoFactorAuthentication::AuthAppSelectionPresenter,
          TwoFactorAuthentication::PhoneSelectionPresenter,
          TwoFactorAuthentication::WebauthnPlatformSelectionPresenter,
          TwoFactorAuthentication::BackupCodeSelectionPresenter,
          TwoFactorAuthentication::WebauthnSelectionPresenter,
          TwoFactorAuthentication::PivCacSelectionPresenter,
        ]
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
end
