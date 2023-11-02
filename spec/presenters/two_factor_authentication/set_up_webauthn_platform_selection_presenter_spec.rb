require 'rails_helper'

RSpec.describe TwoFactorAuthentication::SetUpWebauthnPlatformSelectionPresenter do
  let(:user_without_mfa) { create(:user) }
  let(:user_with_mfa) { create(:user) }
  let(:configuration) {}
  let(:presenter_without_mfa) do
    described_class.new(user: user_without_mfa)
  end
  let(:presenter_with_mfa) do
    described_class.new(user: user_with_mfa)
  end
  subject(:presenter) do
    TwoFactorAuthentication::SetUpWebauthnPlatformSelectionPresenter.new(
      user:,
      configuration: user.webauthn_configurations.platform_authenticators.first,
    )
  end

  describe '#type' do
    it 'returns webauthn_platform' do
      expect(presenter_without_mfa.type).to eq 'webauthn_platform'
    end
  end

  describe '#render_in' do
    let(:user) { create(:user) }
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
          expect(component.passkey_supported_only?).to be(true)
        end

        presenter.render_in(view_context)
      end
    end
  end

  describe '#mfa_configuration' do
    it 'returns an empty string when user has not configured this authenticator' do
      expect(presenter_without_mfa.mfa_configuration_description).to eq('')
    end

    it 'returns an # added when user has configured this authenticator' do
      create(:webauthn_configuration, platform_authenticator: true, user: user_with_mfa)
      expect(presenter_with_mfa.mfa_configuration_description).to eq(
        t(
          'two_factor_authentication.two_factor_choice_options.no_count_configuration_added',
          count: 1,
        ),
      )
    end
  end
end
