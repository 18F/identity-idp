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

  let(:multiple_required_methods_enabled) { false }
  let(:aal3_required) { true }
  let(:service_provider_mfa_policy) do
    instance_double(ServiceProviderMfaPolicy,
                    aal3_required?: aal3_required,
                    multiple_required_methods_enabled?: multiple_required_methods_enabled)
  end

  before do
    allow(presenter).to receive(
      :service_provider_mfa_policy,
    ).and_return(service_provider_mfa_policy)
  end

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
      let(:aal3_required) { true }

      let(:expected_help_text) do
        t('instructions.mfa.piv_cac.confirm_piv_cac_only_html')
      end
      it 'finds the PIV/CAC only help text' do
        expect(presenter.help_text).to eq expected_help_text
      end
    end
    context 'without AAL3 required' do
      let(:aal3_required) { false }
      it 'finds the help text' do
        expect(presenter.help_text).to eq expected_help_text
      end
    end
  end

  describe '#link_text' do
    let(:aal3_required) { true }

    context 'with multiple AAL3 methods' do
      let(:multiple_required_methods_enabled) { true }

      it 'supplies link text' do
        expect(presenter.link_text).to eq(t('two_factor_authentication.piv_cac_webauthn_available'))
      end
    end
    context 'with only one AAL3 method do' do
      let(:multiple_required_methods_enabled) { false }

      it ' supplies no link text' do
        expect(presenter.link_text).to eq('')
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
