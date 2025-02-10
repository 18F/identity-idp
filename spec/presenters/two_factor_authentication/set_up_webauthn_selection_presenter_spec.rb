require 'rails_helper'

RSpec.describe TwoFactorAuthentication::SetUpWebauthnSelectionPresenter do
  let(:user) { create(:user) }
  let(:presenter) { described_class.new(user:) }

  describe '#type' do
    subject(:type) { presenter.type }

    it 'returns webauthn' do
      expect(type).to eq(:webauthn)
    end
  end

  describe '#render_in' do
    let(:view_context) { ActionController::Base.new.view_context }
    subject(:rendered) { presenter.render_in(view_context) { 'content' } }

    it 'renders a WebauthnInputComponent' do
      expect(view_context).to receive(:render) do |component, &block|
        expect(component).to be_instance_of(WebauthnInputComponent)
        expect(block.call).to eq('content')
      end

      rendered
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
      let(:user) { create(:user, :with_webauthn) }

      it 'returns text with number of added authenticators' do
        expect(mfa_configuration_description).to eq(
          t(
            'two_factor_authentication.two_factor_choice_options.configurations_added',
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
