require 'rails_helper'

describe TwoFactorAuthCode::PivCacAuthenticationPresenter do
  include Rails.application.routes.url_helpers
  include ActionView::Helpers::TagHelper

  def presenter_with(arguments = {}, view = ActionController::Base.new.view_context)
    TwoFactorAuthCode::PivCacAuthenticationPresenter.new(data: arguments, view: view)
  end

  let(:user_email) { 'user@example.com' }
  let(:reauthn) {}
  let(:presenter) { presenter_with(reauthn: reauthn, user_email: user_email) }

  describe '#header' do
    let(:expected_header) { t('two_factor_authentication.piv_cac_header_text') }

    it { expect(presenter.header).to eq expected_header }
  end

  describe '#help_text' do
    let(:expected_help_text) do
      t('instructions.mfa.piv_cac.confirm_piv_cac_html',
        email: content_tag(:strong, user_email),
        app: content_tag(:strong, APP_NAME))
    end

    context 'with AAL3 required, and only one method enabled' do
      let(:expected_help_text) do
        t('instructions.mfa.piv_cac.confirm_piv_cac_only_html')
      end
      it 'finds the PIV/CAC only help text' do
        aal3_policy = instance_double('AAL3Policy')
        allow(aal3_policy).to receive(:aal3_required?).and_return true
        allow(aal3_policy).to receive(:multiple_aal3_configurations?).and_return false
        allow(presenter).to receive(:aal3_policy).and_return aal3_policy
        expect(presenter.help_text).to eq expected_help_text
      end
    end
    context 'without AAL3 required' do
      it 'finds the help text' do
        aal3_policy = instance_double('AAL3Policy')
        allow(aal3_policy).to receive(:aal3_required?).and_return false
        allow(presenter).to receive(:aal3_policy).and_return aal3_policy
        expect(presenter.help_text).to eq expected_help_text
      end
    end
  end

  describe '#piv_cac_capture_text' do
    let(:expected_text) { t('forms.piv_cac_mfa.submit') }

    it { expect(presenter.piv_cac_capture_text).to eq expected_text }
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
