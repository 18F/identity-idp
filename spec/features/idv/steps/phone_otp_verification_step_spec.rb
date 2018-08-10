require 'rails_helper'

feature 'phone otp verification step spec', :idv_job do
  include IdvStepHelper

  let(:otp_code) { '777777' }

  before do
    allow(Idv::PhoneConfirmationOtpGenerator).to receive(:generate_otp).and_return(otp_code)
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

    expect(page).to have_content(t('devise.two_factor_authentication.invalid_otp'))
    expect(current_path).to eq(idv_otp_verification_path)

    # Enter the correct code
    fill_in 'code', with: '777777'
    click_submit_default

    expect(page).to have_content(t('idv.titles.session.review'))
    expect(page).to have_current_path(idv_review_path)
  end

  it 'rate limits the number of OTPs that can be sent' do
    max_attempts = Figaro.env.otp_delivery_blocklist_maxretry.to_i

    user = user_with_2fa

    start_idv_from_sp
    complete_idv_steps_before_phone_otp_verification_step

    max_attempts.times do
      click_link t('links.two_factor_authentication.get_another_code')
    end

    expect(page).to have_content t('titles.account_locked')
    expect(page).to have_content t(
      'devise.two_factor_authentication.max_otp_requests_reached'
    )

    expect_rate_limit_circumvention_to_be_disallowed(user)
    expect_rate_limit_to_expire(user)
  end

  it 'limits the number of OTP attempts' do
    user = user_with_2fa

    start_idv_from_sp
    complete_idv_steps_before_phone_otp_verification_step(user)

    3.times do
      fill_in('code', with: 'bad-code')
      click_button t('forms.buttons.submit.default')
    end

    expect(page).to have_content t('titles.account_locked')
    expect(page).
      to have_content t('devise.two_factor_authentication.max_otp_login_attempts_reached')

    expect_rate_limit_circumvention_to_be_disallowed(user)
    expect_rate_limit_to_expire(user)
  end

  it 'rejects OTPs after they are expired' do
    expiration_minutes = Figaro.env.otp_valid_for.to_i + 1

    start_idv_from_sp
    complete_idv_steps_before_phone_otp_verification_step

    Timecop.travel(expiration_minutes.minutes.from_now) do
      fill_in(:code, with: otp_code)
      click_button t('forms.buttons.submit.default')

      expect(page).to have_content(t('devise.two_factor_authentication.invalid_otp'))
      expect(page).to have_current_path(idv_otp_verification_path)
    end
  end

  context 'cancelling IdV' do
    it_behaves_like 'cancel at idv step', :phone_otp_verification
    it_behaves_like 'cancel at idv step', :phone_otp_verification, :oidc
    it_behaves_like 'cancel at idv step', :phone_otp_verification, :saml
  end

  def expect_rate_limit_circumvention_to_be_disallowed(user)
    # Attempting to send another OTP does not send an OTP and shows lockout message
    allow(SmsOtpSenderJob).to receive(:perform_now)
    allow(SmsOtpSenderJob).to receive(:perform_later)

    start_idv_from_sp
    complete_idv_steps_before_phone_otp_verification_step(user)

    expect(page).to have_content t('titles.account_locked')
    expect(SmsOtpSenderJob).to_not have_received(:perform_now)
    expect(SmsOtpSenderJob).to_not have_received(:perform_later)
  end

  def expect_rate_limit_to_expire(user)
    # Returning after session and lockout expires allows you to try again
    retry_minutes = Figaro.env.lockout_period_in_minutes.to_i + 1
    Timecop.travel retry_minutes.minutes.from_now do
      start_idv_from_sp
      complete_idv_steps_before_phone_otp_verification_step(user)

      fill_in(:code, with: otp_code)
      click_submit_default

      expect(page).to have_content(t('idv.titles.session.review'))
      expect(current_path).to eq(idv_review_path)
    end
  end
end
