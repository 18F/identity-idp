require 'rails_helper'

RSpec.describe TwoFactorAuthCode::PivCacAuthenticationPresenter do
  include Rails.application.routes.url_helpers
  include ActionView::Helpers::TagHelper

  let(:user_email) { 'user@example.com' }
  let(:reauthn) {}
  let(:presenter) { presenter_with(reauthn: reauthn) }

  let(:phishing_resistant_required) { true }
  let(:piv_cac_required) { false }
  let(:service_provider_mfa_policy) do
    instance_double(
      ServiceProviderMfaPolicy,
      phishing_resistant_required?: phishing_resistant_required,
      piv_cac_required?: piv_cac_required,
    )
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
    TwoFactorAuthCode::PivCacAuthenticationPresenter.new(
      data: arguments,
      view: view,
      service_provider: nil,
    )
  end
end
