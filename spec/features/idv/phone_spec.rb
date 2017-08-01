require 'rails_helper'

feature 'Verify phone' do
  include IdvHelper

  scenario 'phone step redirects to fail after max attempts', idv_job: true do
    sign_in_and_2fa_user
    visit verify_session_path
    fill_out_idv_form_ok
    click_idv_continue
    fill_out_financial_form_ok
    click_idv_continue
    click_idv_address_choose_phone

    max_attempts_less_one.times do
      fill_out_phone_form_fail
      click_idv_continue

      expect(current_path).to eq verify_phone_result_path
    end

    fill_out_phone_form_fail
    click_idv_continue
    expect(page).to have_css('.alert-error', text: t('idv.modal.phone.heading'))
  end

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
  end

  scenario 'phone field only allows numbers', js: true, idv_job: true do
    sign_in_and_2fa_user
    visit verify_session_path
    fill_out_idv_form_ok
    click_idv_continue
    fill_out_financial_form_ok
    click_idv_continue

    visit verify_phone_path
    fill_in 'Phone', with: ''
    find('#idv_phone_form_phone').native.send_keys('abcd1234')

    expect(find('#idv_phone_form_phone').value).to eq '+1 234'
  end

  def complete_idv_profile_with_phone(phone)
    fill_out_idv_form_ok
    click_idv_continue
    fill_out_financial_form_ok
    click_idv_continue
    click_idv_address_choose_phone
    fill_out_phone_form_ok(phone)
    click_idv_continue
  end
end
