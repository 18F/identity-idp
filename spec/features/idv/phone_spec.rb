require 'rails_helper'

feature 'Verify phone' do
  include IdvHelper

  context 'Idv phone and user phone are different', idv_job: true do
    scenario 'prompts to confirm phone' do
      user = create(
        :user, :signed_up,
        phone: '+1 (416) 555-0190',
        password: Features::SessionHelper::VALID_PASSWORD
      )

      sign_in_and_2fa_user(user)
      visit verify_session_path
      complete_idv_profile_with_phone('555-555-0000')

      fill_in 'code', with: 'not a valid code 😟'
      click_submit_default
      expect(page).to have_link t('forms.two_factor.try_again'), href: verify_phone_path

      enter_correct_otp_code_for_user(user)
      fill_in :user_password, with: user_password
      click_continue
      click_acknowledge_personal_key

      expect(current_path).to eq account_path
    end

    scenario 'user cannot re-enter phone step and change phone after confirmation', :idv_job do
      user = sign_in_and_2fa_user

      visit verify_session_path
      fill_out_idv_form_ok
      click_idv_continue
      click_idv_address_choose_phone
      fill_out_phone_form_ok
      click_idv_continue
      choose_idv_otp_delivery_method_sms
      enter_correct_otp_code_for_user(user)

      visit verify_phone_path
      expect(current_path).to eq(verify_review_path)
    end
  end

  def complete_idv_profile_with_phone(phone)
    fill_out_idv_form_ok
    click_idv_continue
    click_idv_address_choose_phone
    fill_out_phone_form_ok(phone)
    click_idv_continue
    choose_idv_otp_delivery_method_sms
  end
end
