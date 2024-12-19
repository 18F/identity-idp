require 'rails_helper'

RSpec.feature 'sign in with piv/cac' do
  include SamlAuthHelper
  include OidcAuthHelper

  let(:user) { create(:user, :with_piv_or_cac, :with_phone) }

  before do
    sign_in_before_2fa(user)
  end

  context 'with piv/cac mismatch error' do
    before do
      stub_piv_cac_service(error: 'user.piv_cac_mismatch')
    end

    it 'allows a user to add a replacement piv after authenticating with another method' do
      click_on t('forms.piv_cac_login.submit')
      follow_piv_cac_redirect

      expect(page).to have_current_path(login_two_factor_piv_cac_mismatch_path)
      expect(page).to have_button(t('two_factor_authentication.piv_cac_mismatch.skip'))

      click_on t('two_factor_authentication.piv_cac_mismatch.cta')

      expect(page).to have_current_path(login_two_factor_options_path)
      expect(page).to have_content(t('two_factor_authentication.piv_cac_mismatch.2fa_before_add'))
      expect(page).to have_field(t('two_factor_authentication.login_options.sms'))
      expect(page).to have_field(
        t('two_factor_authentication.login_options.piv_cac'),
        disabled: true,
      )

      select_2fa_option(:sms)
      fill_in_code_with_last_phone_otp
      click_submit_default

      expect(page).to have_current_path(setup_piv_cac_path)
      expect(page).to have_button(t('mfa.skip'))

      stub_piv_cac_service
      fill_in t('forms.totp_setup.totp_step_1'), with: 'New PIV'
      click_on t('forms.piv_cac_setup.submit')
      follow_piv_cac_redirect

      expect(page).to have_current_path(account_path)
      within(page.find('.card', text: t('headings.account.federal_employee_id'))) do
        expect(page).to have_css('lg-manageable-authenticator', count: 2)
      end
    end

    context 'with partner requiring piv/cac' do
      before do
        visit_idp_from_oidc_sp_with_hspd12_and_require_piv_cac
      end

      it 'does not allow a user to skip adding piv/cac' do
        click_on t('forms.piv_cac_login.submit')
        follow_piv_cac_redirect

        expect(page).to have_current_path(login_two_factor_piv_cac_mismatch_path)
        expect(page).not_to have_button(t('two_factor_authentication.piv_cac_mismatch.skip'))

        click_on t('two_factor_authentication.piv_cac_mismatch.cta')

        expect(page).to have_current_path(login_two_factor_options_path)
        expect(page).to have_content(t('two_factor_authentication.piv_cac_mismatch.2fa_before_add'))
        expect(page).to have_field(t('two_factor_authentication.login_options.sms'))
        expect(page).to have_field(
          t('two_factor_authentication.login_options.piv_cac'),
          disabled: true,
        )

        select_2fa_option(:sms)
        fill_in_code_with_last_phone_otp
        click_submit_default

        expect(page).to have_current_path(setup_piv_cac_path)
        expect(page).not_to have_button(t('mfa.skip'))

        stub_piv_cac_service
        fill_in t('forms.totp_setup.totp_step_1'), with: 'New PIV'
        click_on t('forms.piv_cac_setup.submit')
        follow_piv_cac_redirect

        expect(page).to have_current_path(sign_up_completed_path)

        click_agree_and_continue
        expect(oidc_decoded_id_token[:x509_presented]).to eq(true)
        expect(oidc_decoded_id_token[:x509_subject]).to be_present
      end
    end

    context 'if the user chooses to skip adding piv/cac when prompted with mismatch' do
      it 'allows the user to authenticate with another method' do
        click_on t('forms.piv_cac_login.submit')
        follow_piv_cac_redirect

        expect(page).to have_current_path(login_two_factor_piv_cac_mismatch_path)
        expect(page).to have_button(t('two_factor_authentication.piv_cac_mismatch.skip'))

        click_on t('two_factor_authentication.piv_cac_mismatch.skip')

        expect(page).to have_current_path(login_two_factor_options_path)
        expect(page).not_to have_content(
          t('two_factor_authentication.piv_cac_mismatch.2fa_before_add'),
        )
        expect(page).to have_field(t('two_factor_authentication.login_options.sms'))
        expect(page).to have_field(
          t('two_factor_authentication.login_options.piv_cac'),
          disabled: true,
        )

        select_2fa_option(:sms)
        fill_in_code_with_last_phone_otp
        click_submit_default

        expect(page).to have_current_path(account_path)
      end
    end

    context 'with no other mfa methods available' do
      let(:user) { create(:user, :with_piv_or_cac) }

      it 'prompts the user to reset their account' do
        click_on t('forms.piv_cac_login.submit')
        follow_piv_cac_redirect

        expect(page).to have_current_path(login_two_factor_piv_cac_mismatch_path)
        expect(page).not_to have_button(t('two_factor_authentication.piv_cac_mismatch.cta'))
        expect(page).not_to have_button(t('two_factor_authentication.piv_cac_mismatch.skip'))
        expect(page).to have_link(t('two_factor_authentication.piv_cac_mismatch.delete_account'))

        click_on t('two_factor_authentication.piv_cac_mismatch.delete_account')

        expect(page).to have_current_path(account_reset_recovery_options_path)
      end
    end
  end
end
