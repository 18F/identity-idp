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
      click_submit_default
      click_acknowledge_personal_key

      expect(current_path).to eq account_path
    end

    scenario 'phone number with no voice otp support only allows sms delivery' do
      guam_phone = '671-555-5000'
      user = create(
        :user, :signed_up,
        otp_delivery_preference: 'voice',
        password: Features::SessionHelper::VALID_PASSWORD
      )

      sign_in_and_2fa_user(user)
      visit verify_session_path

      allow(VoiceOtpSenderJob).to receive(:perform_later)
      allow(SmsOtpSenderJob).to receive(:perform_later)

      complete_idv_profile_with_phone(guam_phone)

      expect(current_path).to eq login_two_factor_path(otp_delivery_preference: :sms)
      expect(VoiceOtpSenderJob).to_not have_received(:perform_later)
      expect(SmsOtpSenderJob).to have_received(:perform_later)
      expect(page).to_not have_content(t('links.two_factor_authentication.resend_code.phone'))
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

  context 'failing to verify 2FA phone' do
    scenario 'requires verifying and confirming a different phone', :idv_job do
      phone_number_that_will_fail_verification = '+1 (555) 555-5555'

      user = create(
        :user, :signed_up,
        phone: phone_number_that_will_fail_verification,
        password: Features::SessionHelper::VALID_PASSWORD
      )
      sign_in_and_2fa_user(user)
      visit verify_session_path
      fill_out_idv_form_ok
      click_idv_continue
      click_idv_address_choose_phone

      fill_in 'Phone', with: user.phone
      click_idv_continue

      expect(page).to have_content(t('idv.modal.phone.heading'))

      fill_in 'Phone', with: '+1 (555) 555-5000'
      click_idv_continue

      choose_idv_otp_delivery_method_sms
      enter_correct_otp_code_for_user(user)
      fill_in :user_password, with: user_password
      click_submit_default
      click_acknowledge_personal_key

      expect(current_path).to eq account_path
    end
  end

  scenario 'phone field only allows numbers', js: true, idv_job: true do
    sign_in_and_2fa_user
    visit verify_session_path
    fill_out_idv_form_ok
    click_idv_continue

    visit verify_phone_path
    fill_in 'Phone', with: ''
    find('#idv_phone_form_phone').native.send_keys('abcd1234')

    expect(find('#idv_phone_form_phone').value).to eq '1 (234) '
  end

  scenario 'phone field does not format international numbers', :js, idv_job: true do
    sign_in_and_2fa_user
    visit verify_session_path
    fill_out_idv_form_ok
    click_idv_continue

    visit verify_phone_path
    fill_in 'Phone', with: ''
    find('#idv_phone_form_phone').native.send_keys('+81543543643')

    expect(find('#idv_phone_form_phone').value).to eq '+1 (815) 435-4364'
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
