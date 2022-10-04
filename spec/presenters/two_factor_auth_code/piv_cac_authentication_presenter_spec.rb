require 'rails_helper'

describe TwoFactorAuthCode::PivCacAuthenticationPresenter do
  include Rails.application.routes.url_helpers
  include ActionView::Helpers::TagHelper

  let(:user_email) { 'user@example.com' }
  let(:reauthn) {}
  let(:presenter) { presenter_with(reauthn: reauthn, user_email: user_email) }

  let(:allow_user_to_switch_method) { false }
  let(:phishing_resistant_required) { true }
  let(:piv_cac_required) { false }
  let(:service_provider_mfa_policy) do
    instance_double(
      ServiceProviderMfaPolicy,
      phishing_resistant_required?: phishing_resistant_required,
      piv_cac_required?: piv_cac_required,
      allow_user_to_switch_method?: allow_user_to_switch_method,
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

  describe '#piv_cac_help' do
    let(:phishing_resistant_required) { false }
    let(:piv_cac_required) { false }

    it 'returns help text' do
      expected_help_text = t(
        'instructions.mfa.piv_cac.confirm_piv_cac_html',
        email: content_tag(:strong, user_email),
        app_name: content_tag(:strong, APP_NAME),
      )
      expect(presenter.piv_cac_help).to eq expected_help_text
    end

    context 'with PIV/CAC only requested' do
      let(:phishing_resistant_required) { true }
      let(:piv_cac_required) { true }

      context 'with a user who only has a PIV' do
        let(:allow_user_to_switch_method) { false }

        it 'returns the PIV only help text' do
          expect(presenter.piv_cac_help).to eq(
            t('instructions.mfa.piv_cac.confirm_piv_cac_only_html'),
          )
        end
      end

      context 'with a user who has a PIV and security key' do
        let(:allow_user_to_switch_method) { false }

        it 'returns the PIV only help text' do
          expect(presenter.piv_cac_help).to eq(
            t('instructions.mfa.piv_cac.confirm_piv_cac_only_html'),
          )
        end
      end
    end

    context 'with phishing-resistant requested' do
      let(:phishing_resistant_required) { true }
      let(:piv_cac_required) { false }

      context 'with a user who only has a PIV' do
        let(:allow_user_to_switch_method) { false }

        it 'returns the PIV only help text' do
          expect(presenter.piv_cac_help).to eq(
            t('instructions.mfa.piv_cac.confirm_piv_cac_only_html'),
          )
        end
      end

      context 'with a user who has a PIV and security key' do
        let(:allow_user_to_switch_method) { true }

        it 'returns the PIV or phishing-resistant help text' do
          expect(presenter.piv_cac_help).to eq(
            t('instructions.mfa.piv_cac.confirm_piv_cac_or_aal3_html'),
          )
        end
      end
    end
  end

  describe 'help_text' do
    it 'supplies no help text' do
      expect(presenter.help_text).to eq('')
    end
  end

  describe '#link_text' do
    let(:phishing_resistant_required) { true }

    context 'with multiple phishing-resistant methods' do
      let(:allow_user_to_switch_method) { true }

      it 'supplies link text' do
        expect(presenter.link_text).to eq(t('two_factor_authentication.piv_cac_webauthn_available'))
      end
    end
    context 'with only one phishing-resistant method do' do
      let(:allow_user_to_switch_method) { false }

      it ' supplies no link text' do
        expect(presenter.link_text).to eq('')
      end
    end
  end

  describe '#fallback_question' do
    context 'when the user can switch to a different method' do
      let(:allow_user_to_switch_method) { true }

      it 'returns a question about switching methods' do
        expect(presenter.fallback_question).to eq(
          t('two_factor_authentication.piv_cac_fallback.question'),
        )
      end
    end

    context 'when the user cannot switch to a different method' do
      let(:allow_user_to_switch_method) { false }

      it 'returns an empty string' do
        expect(presenter.fallback_question).to eq('')
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
    TwoFactorAuthCode::PivCacAuthenticationPresenter.new(
      data: arguments,
      view: view,
      service_provider: nil,
    )
  end
end
