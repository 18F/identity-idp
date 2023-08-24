require 'rails_helper'

RSpec.describe TwoFactorAuthentication::WebauthnPlatformSelectionPresenter do
  let(:user) { create(:user) }
  subject(:presenter) do
    TwoFactorAuthentication::WebauthnPlatformSelectionPresenter.new(
      user:,
      configuration: user.webauthn_configurations.platform_authenticators.first,
    )
  end

  describe '#type' do
    it 'returns webauthn_platform' do
      expect(presenter.type).to eq 'webauthn_platform'
    end
  end

  describe '#render_in' do
    it 'renders a WebauthnInputComponent' do
      view_context = instance_double(ActionView::Base)
      expect(view_context).to receive(:render) do |component, &block|
        expect(component).to be_instance_of(WebauthnInputComponent)
        expect(component.passkey_supported_only?).to be(true)
        expect(block.call).to eq('content')
      end

      presenter.render_in(view_context) { 'content' }
    end

    context 'with configured authenticator' do
      let(:user) { create(:user, :with_webauthn_platform) }

      it 'renders a WebauthnInputComponent with passkey_supported_only false' do
        view_context = instance_double(ActionView::Base)
        expect(view_context).to receive(:render) do |component, &block|
          expect(component.passkey_supported_only?).to be(false)
        end

        presenter.render_in(view_context)
      end
    end
  end

  describe '#mfa_configuration' do
    it 'returns an empty string when user has not configured this authenticator' do
      expect(presenter.mfa_configuration_description).to eq('')
    end

    context 'with configured authenticator' do
      let(:user) { create(:user, :with_webauthn_platform) }

      it 'returns the translated string for added when user has configured this authenticator' do
        expect(presenter.mfa_configuration_description).to eq(
          t(
            'two_factor_authentication.two_factor_choice_options.no_count_configuration_added',
          ),
        )
      end
    end
  end
end
