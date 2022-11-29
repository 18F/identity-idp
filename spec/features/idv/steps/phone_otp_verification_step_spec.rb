require 'rails_helper'

feature 'phone otp verification step spec', :js do
  include IdvStepHelper

  it 'requires the user to enter the correct otp before continuing' do
    user = user_with_2fa

    start_idv_from_sp
    complete_idv_steps_before_phone_otp_verification_step(user)

    # Attempt to bypass the step
    visit idv_review_path
    expect(current_path).to eq(idv_otp_verification_path)

    # Enter an incorrect otp
    fill_in 'code', with: '000000'
    click_submit_default

    expect(page).to have_content(t('two_factor_authentication.invalid_otp_html', count: 2))
    expect(current_path).to eq(idv_otp_verification_path)

    # Enter the correct code
    fill_in_code_with_last_phone_otp
    click_submit_default

    expect(page).to have_content(t('idv.titles.session.review', app_name: APP_NAME))
    expect(page).to have_current_path(idv_review_path)
  end

  it 'rejects OTPs after they are expired' do
    expiration_minutes = TwoFactorAuthenticatable::DIRECT_OTP_VALID_FOR_MINUTES + 1

    start_idv_from_sp
    complete_idv_steps_before_phone_otp_verification_step

    travel_to(expiration_minutes.minutes.from_now) do
      fill_in_code_with_last_phone_otp
      click_button t('forms.buttons.submit.default')

      expect(page).to have_content(t('two_factor_authentication.invalid_otp_html', count: 2))
      expect(page).to have_current_path(idv_otp_verification_path)
    end
  end

  it 'allows the user to resend the otp' do
    start_idv_from_sp
    complete_idv_steps_before_phone_otp_verification_step

    sent_message_count = Telephony::Test::Message.messages.count

    click_on t('links.two_factor_authentication.send_another_code')

    expect(Telephony::Test::Message.messages.count).to eq(sent_message_count + 1)
    expect(current_path).to eq(idv_otp_verification_path)

    fill_in_code_with_last_phone_otp
    click_submit_default

    expect(page).to have_content(t('idv.titles.session.review', app_name: APP_NAME))
    expect(page).to have_current_path(idv_review_path)
  end

  it 'redirects back to the step with an error if Telephony raises an error on resend' do
    start_idv_from_sp
    complete_idv_steps_before_phone_otp_verification_step

    telephony_error = Telephony::TelephonyError.new('error message')
    response = Telephony::Response.new(
      success: false,
      error: telephony_error,
      extra: {},
    )
    allow(Telephony).to receive(:send_confirmation_otp).and_return(response)

    click_on t('links.two_factor_authentication.send_another_code')

    expect(page).to have_content(I18n.t('telephony.error.friendly_message.generic'))
    expect(page).to have_current_path(idv_phone_path)

    allow(Telephony).to receive(:send_confirmation_otp).and_call_original

    fill_out_phone_form_ok
    click_idv_continue
    choose_idv_otp_delivery_method_sms

    calling_area_error = Telephony::InvalidCallingAreaError.new('error message')
    response = Telephony::Response.new(
      success: false,
      error: calling_area_error,
      extra: {},
    )
    allow(Telephony).to receive(:send_confirmation_otp).and_return(response)

    click_on t('links.two_factor_authentication.send_another_code')

    expect(page).to have_content(calling_area_error.friendly_message)
    expect(page).to have_current_path(idv_phone_path)
  end
end
