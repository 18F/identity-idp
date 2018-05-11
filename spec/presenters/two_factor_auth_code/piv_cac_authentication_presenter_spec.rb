require 'rails_helper'

describe TwoFactorAuthCode::PivCacAuthenticationPresenter do
  include Rails.application.routes.url_helpers
  include ActionView::Helpers::TagHelper

  let(:user_email) { 'user@example.com' }
  let(:reauthn) { }
  let(:presenter) { presenter_with(reauthn: reauthn, user_email: user_email) }

  describe '#header' do
    let(:expected_header) { t('devise.two_factor_authentication.piv_cac_header_text') }

    it { expect(presenter.header).to eq expected_header }
  end

  describe '#help_text' do
    let(:expected_help_text) do
      t('instructions.mfa.piv_cac.confirm_piv_cac_html',
        email: content_tag(:strong, user_email),
        app: content_tag(:strong, APP_NAME))
    end

    it { expect(presenter.help_text).to eq expected_help_text }
  end

  describe '#piv_cac_capture_text' do
    let(:expected_text) { t('forms.piv_cac_mfa.submit') }

    it { expect(presenter.piv_cac_capture_text).to eq expected_text }
  end

  describe '#fallback_links' do
    it 'has two options' do
      expect(presenter.fallback_links.count).to eq 2
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

  def presenter_with(arguments = {}, view = ActionController::Base.new.view_context)
    TwoFactorAuthCode::PivCacAuthenticationPresenter.new(data: arguments, view: view)
  end
end
