require 'rails_helper'

describe TwoFactorOptionsPresenter do
  include Rails.application.routes.url_helpers
  include RequestHelper

  let(:user_agent) do
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_6) AppleWebKit/537.36 \
(KHTML, like Gecko) Chrome/78.0.3904.87 Safari/537.36'
  end

  let(:presenter) do
    described_class.new(user_agent: user_agent)
  end


  describe '#options' do
    it 'supplies all the options for a user' do
      expect(presenter.options.map(&:class)).to eq [
        TwoFactorAuthentication::AuthAppSelectionPresenter,
        TwoFactorAuthentication::WebauthnSelectionPresenter,
        TwoFactorAuthentication::PhoneSelectionPresenter,
        TwoFactorAuthentication::PivCacSelectionPresenter,
        TwoFactorAuthentication::BackupCodeSelectionPresenter,
      ]
    end

    context 'when an AAL3 only SP is being used' do
      let(:service_provider) { create(:service_provider, aal: 3) }
      let(:sp_session) { { issuer: service_provider.issuer, aal_level_requested: 3 } }
      let(:session) { { auth_method: 'phone', sp: sp_session } }

      let(:presenter) do
        described_class.new(user_agent: user_agent, user: user_with_2fa, session: session)
      end

      it 'only displays AAL3 MFA methods' do
        expect(presenter.options.map(&:class)).to eq [
          TwoFactorAuthentication::WebauthnSelectionPresenter,
          TwoFactorAuthentication::PivCacSelectionPresenter,
        ]
      end
    end

    context 'when hide_phone_mfa_signup is enabled' do
      before do
        allow(FeatureManagement).to receive(:hide_phone_mfa_signup?).and_return(true)
      end

      it 'supplies all the options except phone' do
        expect(presenter.options.map(&:class)).to eq [
          TwoFactorAuthentication::AuthAppSelectionPresenter,
          TwoFactorAuthentication::WebauthnSelectionPresenter,
          TwoFactorAuthentication::PivCacSelectionPresenter,
          TwoFactorAuthentication::BackupCodeSelectionPresenter,
        ]
      end
    end
  end
end
