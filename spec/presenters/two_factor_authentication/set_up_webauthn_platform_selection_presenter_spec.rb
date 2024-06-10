require 'rails_helper'

RSpec.describe TwoFactorAuthentication::SetUpWebauthnPlatformSelectionPresenter do
  let(:user) { create(:user) }
  subject(:presenter) do
    TwoFactorAuthentication::SetUpWebauthnPlatformSelectionPresenter.new(user:)
  end

  describe '#type' do
    it 'returns webauthn_platform' do
      expect(presenter.type).to eq(:webauthn_platform)
    end
  end

  describe '#render_in' do
    let(:view_context) { instance_double(ActionView::Base) }
    subject(:rendered) { presenter.render_in(view_context) { 'content' } }

    it 'renders a WebauthnInputComponent' do
      expect(view_context).to receive(:render) do |component, &block|
        expect(component).to be_instance_of(WebauthnInputComponent)
        expect(component.passkey_supported_only?).to be(true)
        expect(block.call).to eq('content')
      end

      rendered
    end

    context 'with configured authenticator' do
      let(:user) { create(:user, :with_webauthn_platform) }

      it 'renders a WebauthnInputComponent with passkey_supported_only false' do
        expect(view_context).to receive(:render) do |component|
          expect(component.passkey_supported_only?).to be(true)
        end

        rendered
      end
    end
  end

  describe '#mfa_configuration_description' do
    subject(:mfa_configuration_description) { presenter.mfa_configuration_description }

    context 'when user has not configured this authenticator' do
      let(:user) { create(:user) }

      it 'returns an empty string' do
        expect(mfa_configuration_description).to eq('')
      end
    end

    context 'when user has configured this authenticator' do
      let(:user) { create(:user, :with_webauthn_platform) }

      it 'returns text with number of added authenticators' do
        expect(mfa_configuration_description).to eq(
          t(
            'two_factor_authentication.two_factor_choice_options.no_count_configuration_added',
            count: 1,
          ),
        )
      end
    end
  end

  describe '#phishing_resistant?' do
    subject(:phishing_resistant) { presenter.phishing_resistant? }

    it { expect(phishing_resistant).to eq(true) }
  end
end
