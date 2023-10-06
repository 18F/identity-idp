require 'rails_helper'

RSpec.describe TwoFactorAuthCode::WebauthnAuthenticationPresenter do
  include Rails.application.routes.url_helpers

  let(:view) { ActionController::Base.new.view_context }
  let(:reauthn) {}
  let(:credentials) { [] }
  subject(:presenter) do
    TwoFactorAuthCode::WebauthnAuthenticationPresenter.new(
      data: { reauthn:, credentials: },
      service_provider: nil,
      view: view,
      platform_authenticator: platform_authenticator,
    )
  end

  let(:phishing_resistant_required) { false }
  let(:platform_authenticator) { false }
  let(:multiple_factors_enabled) { false }

  describe '#webauthn_help' do
    let(:phishing_resistant_required) { false }

    it 'returns the help text for security key' do
      expect(presenter.webauthn_help).to eq(t('instructions.mfa.webauthn.confirm_webauthn'))
    end

    context 'with a platform authenticator' do
      let(:platform_authenticator) { true }

      it 'returns the help text for a platform authenticator' do
        expect(presenter.webauthn_help).to eq(
          t(
            'instructions.mfa.webauthn.confirm_webauthn_platform',
            app_name: APP_NAME,
          ),
        )
      end
    end
  end

  describe '#authenticate_button_text' do
    context 'with a roaming authenticator' do
      it 'renders the roaming authenticator button text' do
        expect(presenter.authenticate_button_text).to eq(
          t('two_factor_authentication.webauthn_use_key'),
        )
      end
    end

    context 'with a platform authenticator' do
      let(:platform_authenticator) { true }

      it 'renders the platform authenticator button text' do
        expect(presenter.authenticate_button_text).to eq(
          t('two_factor_authentication.webauthn_platform_use_key'),
        )
      end
    end
  end

  describe '#header' do
    context 'with a roaming authenticator' do
      it 'renders the roaming authenticator header' do
        expect(presenter.header).to eq(
          t('two_factor_authentication.webauthn_header_text'),
        )
      end
    end

    context 'with a platform authenticator' do
      let(:platform_authenticator) { true }

      it 'renders the platform authenticator header' do
        expect(presenter.header).to eq(
          t('two_factor_authentication.webauthn_platform_header_text'),
        )
      end
    end
  end

  describe '#troubleshooting_options' do
    let(:phishing_resistant_required) { false }

    it 'includes option to choose another authentication method' do
      expect(presenter.troubleshooting_options.size).to eq(2)
      expect(presenter.troubleshooting_options.first).to satisfy do |c|
        c.url == login_two_factor_options_path &&
          c.content == t('two_factor_authentication.login_options_link_text')
      end
    end

    context 'with platform authenticator' do
      let(:platform_authenticator) { true }

      it 'includes option to learn more about face or touch unlock' do
        expect(presenter.troubleshooting_options.size).to eq(3)
        expect(presenter.troubleshooting_options[1]).to satisfy do |c|
          c.content == t('instructions.mfa.webauthn_platform.learn_more_help')
        end
      end
    end
  end

  describe '#cancel_link' do
    let(:locale) { LinkLocaleResolver.locale }

    context 'reauthn' do
      let(:reauthn) { true }

      it 'returns the account path' do
        expect(presenter.cancel_link).to eq account_path(locale: locale)
      end
    end

    context 'not reauthn' do
      let(:reauthn) { false }

      it 'returns the sign out path' do
        expect(presenter.cancel_link).to eq sign_out_path(locale: locale)
      end
    end
  end

  describe '#credentials' do
    it 'returns credentials from initialized data' do
      expect(presenter.credentials).to eq credentials
    end
  end

  it 'handles multiple locales' do
    I18n.available_locales.each do |locale|
      I18n.locale = locale
      if locale == :en
        expect(presenter.cancel_link).not_to match(%r{/en/})
      else
        expect(presenter.cancel_link).to match(%r{/#{locale}/})
      end
    end
  end
end
