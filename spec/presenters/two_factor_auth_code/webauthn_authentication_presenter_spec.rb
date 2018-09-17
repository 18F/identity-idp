require 'rails_helper'

describe TwoFactorAuthCode::WebauthnAuthenticationPresenter do
  include Rails.application.routes.url_helpers

  let(:view) { ActionController::Base.new.view_context }
  let(:reauthn) {}
  let(:presenter) do
    TwoFactorAuthCode::WebauthnAuthenticationPresenter.
      new(data: { reauthn: reauthn }, view: view)
  end

  describe '#help_text' do
    it 'supplies no help text' do
      expect(presenter.help_text).to eq('')
    end
  end

  describe '#fallback_question' do
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
