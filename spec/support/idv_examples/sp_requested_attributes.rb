shared_examples 'sp requesting attributes' do |sp|
  include SamlAuthHelper
  include IdvStepHelper

  let(:user) { user_with_2fa }
  let(:profile) { create(:profile, :active, :verified, user: user, pii: saved_pii) }
  let(:saved_pii) { Idp::Constants::MOCK_IDV_APPLICANT_WITH_PHONE }

  context 'visiting an SP for the first time' do
    it 'requires the user to verify the attributes submitted to the SP', js: true do
      visit_idp_from_sp_with_ial2(sp)
      sign_in_user(user)
      fill_in_code_with_last_phone_otp
      click_submit_default

      expect(current_path).to eq idv_doc_auth_step_path(step: :welcome)

      complete_all_doc_auth_steps_before_password_step
      fill_in 'Password', with: user.password
      click_continue
      acknowledge_and_confirm_personal_key

      expect(current_path).to eq(sign_up_completed_path)

      within('.requested-attributes') do
        expect(page).to have_content t('help_text.requested_attributes.email')
        expect(page).to have_content user.email
        expect(page).to_not have_content t('help_text.requested_attributes.address')
        expect(page).to_not have_content t('help_text.requested_attributes.birthdate')
        expect(page).to have_content t('help_text.requested_attributes.full_name')
        expect(page).to have_content 'FAKEY MCFAKERSON'
        expect(page).to have_content t('help_text.requested_attributes.phone')
        expect(page).to have_content '+1 202-555-1212'
        expect(page).to have_content t('help_text.requested_attributes.social_security_number')
        expect(page).to have_css(
          '.masked-text__text',
          text: DocAuthHelper::GOOD_SSN,
          visible: :hidden,
        )
      end
    end
  end

  context 'visiting an SP the user has already signed into', js: true do
    let(:user) { user_with_totp_2fa }
    before do
      visit_idp_from_sp_with_ial2(sp)
      sign_in_user(user)
      uncheck(t('forms.messages.remember_device'))
      fill_in_code_with_last_totp(user)
      click_submit_default
      complete_all_doc_auth_steps_before_password_step
      fill_in 'Password', with: user.password
      click_continue
      acknowledge_and_confirm_personal_key
      click_agree_and_continue
      visit account_path
      first(:link, t('links.sign_out')).click
    end

    it 'does not require the user to verify attributes' do
      visit_idp_from_sp_with_ial2(sp)
      sign_in_user(user)
      uncheck(t('forms.messages.remember_device'))
      fill_in_code_with_last_totp(user)
      click_submit_default

      if sp == :oidc
        expect(current_url).to include('http://localhost:7654/auth/result')
      elsif sp == :saml
        if javascript_enabled?
          expect(current_path).to eq(test_saml_decode_assertion_path)
        else
          expect(current_url).to include(api_saml_auth2022_url)
        end
      end
    end
  end

  context 'siging in from an SP after creating a verified account directly' do
    it 'displays the correct values' do
      create(:profile, :active, :verified, user: user, pii: saved_pii)
      visit_idp_from_sp_with_ial2(sp)
      sign_in_user(user)
      uncheck(t('forms.messages.remember_device'))
      fill_in_code_with_last_phone_otp
      sp == :saml ? click_submit_default_twice : click_submit_default

      expect(current_path).to eq(sign_up_completed_path)

      within('.requested-attributes') do
        expect(page).to have_content t('help_text.requested_attributes.email')
        expect(page).to have_content user.email
        expect(page).to_not have_content t('help_text.requested_attributes.address')
        expect(page).to_not have_content t('help_text.requested_attributes.birthdate')
        expect(page).to have_content t('help_text.requested_attributes.full_name')
        expect(page).to have_content 'FAKEY MCFAKERSON'
        expect(page).to have_content t('help_text.requested_attributes.phone')
        expect(page).to have_content '+1 202-555-1212'
        expect(page).to have_content t('help_text.requested_attributes.social_security_number')
        expect(page).to have_content DocAuthHelper::GOOD_SSN
      end
    end
  end
end
