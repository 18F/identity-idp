require 'rails_helper'

feature 'phone otp verification step spec' do
  include IdvStepHelper

  let(:otp_code) { '777777' }

  before do
    allow(Idv::GeneratePhoneConfirmationOtp).to receive(:call).and_return(otp_code)
  end

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

    expect(page).to have_content(t('two_factor_authentication.invalid_otp'))
    expect(current_path).to eq(idv_otp_verification_path)

    # Enter the correct code
    fill_in 'code', with: '777777'
    click_submit_default

    expect(page).to have_content(t('idv.titles.session.review'))
    expect(page).to have_current_path(idv_review_path)
  end

  it 'rejects OTPs after they are expired' do
    expiration_minutes = Figaro.env.otp_valid_for.to_i + 1

    start_idv_from_sp
    complete_idv_steps_before_phone_otp_verification_step

    Timecop.travel(expiration_minutes.minutes.from_now) do
      fill_in(:code, with: otp_code)
      click_button t('forms.buttons.submit.default')

      expect(page).to have_content(t('two_factor_authentication.invalid_otp'))
      expect(page).to have_current_path(idv_otp_verification_path)
    end
  end

  it 'allows the user to resend the otp' do
    start_idv_from_sp
    complete_idv_steps_before_phone_otp_verification_step

    expect(Telephony).to receive(:send_confirmation_otp)

    click_on t('links.two_factor_authentication.get_another_code')

    expect(current_path).to eq(idv_otp_verification_path)

    fill_in 'code', with: '777777'
    click_submit_default

    expect(page).to have_content(t('idv.titles.session.review'))
    expect(page).to have_current_path(idv_review_path)
  end

  it 'redirects back to the step with an error if twilio raises an error on resend' do
    start_idv_from_sp
    complete_idv_steps_before_phone_otp_verification_step

    telephony_error = Telephony::TelephonyError.new('error message')
    allow(Telephony).to receive(:send_confirmation_otp).and_raise(telephony_error)

    click_on t('links.two_factor_authentication.get_another_code')

    expect(page).to have_content(telephony_error.friendly_message)
    expect(page).to have_current_path(idv_phone_path)

    allow(Telephony).to receive(:send_confirmation_otp).and_call_original

    fill_out_phone_form_ok
    click_idv_continue
    choose_idv_otp_delivery_method_sms

    calling_area_error = Telephony::InvalidCallingAreaError.new('error message')
    allow(Telephony).to receive(:send_confirmation_otp).and_raise(calling_area_error)

    click_on t('links.two_factor_authentication.get_another_code')

    expect(page).to have_content(calling_area_error.friendly_message)
    expect(page).to have_current_path(idv_phone_path)
  end

  context 'cancelling IdV' do
    it_behaves_like 'cancel at idv step', :phone_otp_verification
    it_behaves_like 'cancel at idv step', :phone_otp_verification, :oidc
    it_behaves_like 'cancel at idv step', :phone_otp_verification, :saml
  end
end
