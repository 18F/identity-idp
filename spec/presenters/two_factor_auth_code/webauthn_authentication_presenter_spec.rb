require 'rails_helper'

describe TwoFactorAuthCode::WebauthnAuthenticationPresenter do
  include Rails.application.routes.url_helpers

  let(:view) { ActionController::Base.new.view_context }
  let(:reauthn) {}
  let(:presenter) do
    TwoFactorAuthCode::WebauthnAuthenticationPresenter.
      new(data: { reauthn: reauthn },
          service_provider: nil,
          view: view,
          platform_authenticator: platform_authenticator)
  end

  let(:allow_user_to_switch_method) { false }
  let(:phishing_resistant_required) { false }
  let(:platform_authenticator) { false }
  let(:multiple_factors_enabled) { false }
  let(:service_provider_mfa_policy) do
    instance_double(
      ServiceProviderMfaPolicy,
      phishing_resistant_required?: phishing_resistant_required,
      allow_user_to_switch_method?: allow_user_to_switch_method,
      multiple_factors_enabled?: multiple_factors_enabled,
    )
  end

  before do
    allow(presenter).to receive(:service_provider_mfa_policy).and_return service_provider_mfa_policy
  end

  describe '#webauthn_help' do
    context 'with phishing-resistant required' do
      let(:phishing_resistant_required) { true }

      context 'the user only has a security key enabled' do
        let(:allow_user_to_switch_method) { false }

        it 'returns the help text for just the security key' do
          expect(presenter.webauthn_help).to eq(
            t('instructions.mfa.webauthn.confirm_webauthn_only_html'),
          )
        end
      end

      context 'the user has a security key and PIV enabled' do
        let(:allow_user_to_switch_method) { true }

        it 'returns the help text for the security key or PIV' do
          expect(presenter.webauthn_help).to eq(
            t('instructions.mfa.webauthn.confirm_webauthn_or_aal3_html'),
          )
        end
      end
    end

    context 'with phishing-resistant not required' do
      let(:phishing_resistant_required) { false }

      it 'displays the help text' do
        expect(presenter.webauthn_help).to eq(
          t('instructions.mfa.webauthn.confirm_webauthn_html'),
        )
      end
    end

    context 'with a platform authenticator' do
      let(:platform_authenticator) { true }

      it 'returns the help text for a platform authenticator' do
        expect(presenter.webauthn_help).to eq(
          t('instructions.mfa.webauthn.confirm_webauthn_platform_html', app_name: APP_NAME),
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

  describe '#multiple_factors_enabled?' do
    context 'with multiple factors enabled in user policy' do
      let(:multiple_factors_enabled) { true }

      it 'returns true' do
        expect(presenter.multiple_factors_enabled?).to be_truthy
      end
    end

    context 'with multiple factors not enabled for user policy' do
      it 'returns false' do
        expect(presenter.multiple_factors_enabled?).to be_falsey
      end
    end
  end

  describe '#verified_info_text' do
    context 'with a roaming authenticator' do
      it 'renders the roaming authenticator text' do
        expect(presenter.verified_info_text).to eq(
          t('two_factor_authentication.webauthn_verified.info'),
        )
      end
    end

    context 'with a platform authenticator' do
      let(:platform_authenticator) { true }

      it 'renders the platform authenticator text' do
        expect(presenter.verified_info_text).to eq(
          t('two_factor_authentication.webauthn_platform_verified.info'),
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

  describe '#verified_header' do
    context 'with a roaming authenticator' do
      it 'renders the roaming authenticator header' do
        expect(presenter.verified_header).to eq(
          t('two_factor_authentication.webauthn_verified.header'),
        )
      end
    end

    context 'with a platform authenticator' do
      let(:platform_authenticator) { true }

      it 'renders the platform authenticator header' do
        expect(presenter.verified_header).to eq(
          t('two_factor_authentication.webauthn_platform_verified.header'),
        )
      end
    end
  end

  describe '#help_text' do
    it 'supplies no help text' do
      expect(presenter.help_text).to eq('')
    end
  end

  describe '#link_text' do
    let(:phishing_resistant_required) { true }

    context 'with multiple phishing-resistant methods' do
      let(:allow_user_to_switch_method) { true }

      it 'supplies link text' do
        expect(presenter.link_text).to eq(t('two_factor_authentication.webauthn_piv_available'))
      end
    end

    context 'with only one phishing-resistant method do' do
      it 'supplies no link text' do
        expect(presenter.link_text).to eq('')
      end
    end
  end

  describe '#fallback_question' do
    let(:allow_user_to_switch_method) { true }

    it 'supplies a fallback_question' do
      expect(presenter.fallback_question).to \
        eq(t('two_factor_authentication.webauthn_fallback.question'))
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
