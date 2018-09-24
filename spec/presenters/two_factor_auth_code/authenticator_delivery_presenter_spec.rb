require 'rails_helper'

describe TwoFactorAuthCode::AuthenticatorDeliveryPresenter do
  let(:view) { ActionController::Base.new.view_context }
  let(:presenter) do
    TwoFactorAuthCode::AuthenticatorDeliveryPresenter.
      new(data: {}, view: view)
  end

  describe '#header' do
    it 'supplies a header' do
      expect(presenter.header).to eq(t('two_factor_authentication.totp_header_text'))
    end
  end

  describe '#fallback_question' do
    it 'supplies a fallback_question' do
      expect(presenter.fallback_question).to \
        eq(t('two_factor_authentication.totp_fallback.question'))
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
