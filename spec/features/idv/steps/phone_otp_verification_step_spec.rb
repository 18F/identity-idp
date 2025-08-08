require 'rails_helper'

RSpec.feature 'phone otp verification step spec', :js do
  include IdvStepHelper

  it 'requires the user to enter the correct otp before continuing' do
    user = user_with_2fa

    start_idv_from_sp
    complete_idv_steps_before_phone_otp_verification_step(user)

    # Attempt to bypass the step
    visit idv_enter_password_path
    expect(page).to have_current_path(idv_otp_verification_path)

    # Enter an incorrect otp
    fill_in 'code', with: '000000'
    click_submit_default

    expect(page).to have_current_path(idv_otp_verification_path)
    expect(page).to have_content(t('two_factor_authentication.invalid_otp'))

    # Enter the correct code
    fill_in_code_with_last_phone_otp
    click_submit_default

    expect(page).to have_current_path(idv_enter_password_path)
    expect(page).to have_content(t('idv.titles.session.enter_password', app_name: APP_NAME))
  end

  it 'rejects OTPs after they are expired' do
    expiration_minutes = TwoFactorAuthenticatable::DIRECT_OTP_VALID_FOR_MINUTES + 1

    start_idv_from_sp
    complete_idv_steps_before_phone_otp_verification_step

    travel_to(expiration_minutes.minutes.from_now) do
      fill_in_code_with_last_phone_otp
      click_button t('forms.buttons.submit.default')

      expect(page).to have_current_path(idv_otp_verification_path)
      expect(page).to have_content(t('two_factor_authentication.invalid_otp'))
    end
  end

  it 'allows the user to resend the otp' do
    start_idv_from_sp
    complete_idv_steps_before_phone_otp_verification_step
    expect(page).to have_current_path(idv_otp_verification_path)

    sent_message_count = Telephony::Test::Message.messages.count

    click_on t('links.two_factor_authentication.send_another_code')
    expect(page).to have_current_path(idv_otp_verification_path)

    # Failing once
    fill_in I18n.t('components.one_time_code_input.label'), with: '0'
    click_submit_default
    expect(page).to have_current_path(idv_otp_verification_path)
    expect(Telephony::Test::Message.messages.count).to eq(sent_message_count + 1)

    fill_in_code_with_last_phone_otp
    click_submit_default

    expect(page).to have_current_path(idv_enter_password_path)
    expect(page).to have_content(t('idv.titles.session.enter_password', app_name: APP_NAME))
  end

  it 'redirects back to the step with an error if Telephony raises an error on resend' do
    allow(IdentityConfig.store).to receive(:otp_delivery_blocklist_maxretry).and_return(4)

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

    expect(page).to have_current_path(idv_phone_path)
    expect(page).to have_content(I18n.t('telephony.error.friendly_message.generic'))

    allow(Telephony).to receive(:send_confirmation_otp).and_call_original

    fill_out_phone_form_ok('2342255432')
    choose_idv_otp_delivery_method_sms

    calling_area_error = Telephony::InvalidCallingAreaError.new('error message')
    response = Telephony::Response.new(
      success: false,
      error: calling_area_error,
      extra: {},
    )
    allow(Telephony).to receive(:send_confirmation_otp).and_return(response)

    click_on t('links.two_factor_authentication.send_another_code')

    expect(page).to have_current_path(idv_phone_path)
    expect(page).to have_content(calling_area_error.friendly_message)
  end
end
