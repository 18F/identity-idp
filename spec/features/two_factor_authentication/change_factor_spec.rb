require 'rails_helper'

feature 'Changing authentication factor' do
  describe 'requires re-authenticating' do
    let!(:user) { sign_up_and_2fa_loa1_user }

    scenario 'editing password' do
      visit manage_password_path

      expect(page).to have_content t('help_text.change_factor', factor: 'password')

      complete_2fa_confirmation

      expect(current_path).to eq manage_password_path
    end

    scenario 'editing phone number' do
      allow(Figaro.env).to receive(:otp_delivery_blocklist_maxretry).and_return('4')

      mailer = instance_double(ActionMailer::MessageDelivery, deliver_later: true)
      allow(UserMailer).to receive(:phone_changed).with(user).and_return(mailer)

      @previous_phone_confirmed_at = user.reload.phone_confirmed_at
      new_phone = '+1 (703) 555-0100'

      visit manage_phone_path

      expect(page).to have_content t('help_text.change_factor', factor: 'phone')

      complete_2fa_confirmation

      update_phone_number
      expect(page).to have_link t('links.cancel'), href: account_path
      expect(page).to have_link t('forms.two_factor.try_again'), href: manage_phone_path
      expect(page).not_to have_content(
        t('devise.two_factor_authentication.personal_key_fallback.text_html')
      )

      enter_incorrect_otp_code

      expect(page).to have_content t('devise.two_factor_authentication.invalid_otp')
      expect(user.reload.phone).to_not eq new_phone
      expect(page).to have_link t('forms.two_factor.try_again'), href: manage_phone_path

      submit_correct_otp

      expect(current_path).to eq account_path
      expect(UserMailer).to have_received(:phone_changed).with(user)
      expect(mailer).to have_received(:deliver_later)
      expect(page).to have_content new_phone
      expect(user.reload.phone_confirmed_at).to_not eq(@previous_phone_confirmed_at)

      visit login_two_factor_path(otp_delivery_preference: 'sms')
      expect(current_path).to eq account_path
    end

    scenario 'editing phone number with no voice otp support only allows sms delivery' do
      user.update(otp_delivery_preference: 'voice')
      guam_phone = '671-555-5000'

      visit manage_phone_path
      complete_2fa_confirmation

      allow(VoiceOtpSenderJob).to receive(:perform_later)
      allow(SmsOtpSenderJob).to receive(:perform_now)

      update_phone_number(guam_phone)

      expect(current_path).to eq login_two_factor_path(otp_delivery_preference: :sms)
      expect(VoiceOtpSenderJob).to_not have_received(:perform_later)
      expect(SmsOtpSenderJob).to have_received(:perform_now)
      expect(page).to_not have_content(t('links.two_factor_authentication.resend_code.phone'))
    end

    scenario 'waiting too long to change phone number' do
      allow(SmsOtpSenderJob).to receive(:perform_later)

      user = sign_in_and_2fa_user
      old_phone = user.phone
      visit manage_phone_path
      update_phone_number

      Timecop.travel(Figaro.env.reauthn_window.to_i + 1) do
        click_link t('forms.two_factor.try_again'), href: manage_phone_path
        complete_2fa_confirmation_without_entering_otp

        expect(SmsOtpSenderJob).to have_received(:perform_later).
          with(
            code: user.reload.direct_otp,
            phone: old_phone,
            otp_created_at: user.reload.direct_otp_sent_at.to_s
          )

        expect(page).to have_content UserDecorator.new(user).masked_two_factor_phone_number
        expect(page).not_to have_link t('forms.two_factor.try_again')
      end
    end

    context 'resending OTP code to old phone' do
      it 'resends OTP and prompts user to enter their code' do
        allow(SmsOtpSenderJob).to receive(:perform_later)

        user = sign_in_and_2fa_user
        old_phone = user.phone

        Timecop.travel(Figaro.env.reauthn_window.to_i + 1) do
          visit manage_phone_path
          complete_2fa_confirmation_without_entering_otp
          click_link t('links.two_factor_authentication.resend_code.sms')

          expect(SmsOtpSenderJob).to have_received(:perform_later).
            with(
              code: user.reload.direct_otp,
              phone: old_phone,
              otp_created_at: user.reload.direct_otp_sent_at.to_s
            )

          expect(current_path).
            to eq login_two_factor_path(otp_delivery_preference: 'sms')
        end
      end
    end

    scenario 'editing email' do
      visit manage_email_path

      expect(page).to have_content t('help_text.change_factor', factor: 'email')
      complete_2fa_confirmation

      expect(current_path).to eq manage_email_path
    end
  end

  context 'user has authenticator app enabled' do
    it 'allows them to change their email, password, or phone' do
      stub_twilio_service
      sign_in_with_totp_enabled_user

      Timecop.travel(Figaro.env.reauthn_window.to_i + 1) do
        visit manage_email_path
        submit_current_password_and_totp

        expect(current_path).to eq manage_email_path
      end

      Timecop.travel(Figaro.env.reauthn_window.to_i * 3) do
        visit manage_password_path
        submit_current_password_and_totp

        expect(current_path).to eq manage_password_path
      end

      Timecop.travel(Figaro.env.reauthn_window.to_i * 4) do
        visit manage_phone_path
        submit_current_password_and_totp

        expect(current_path).to eq manage_phone_path

        update_phone_number
        expect(page).to have_link t('links.cancel'), href: account_path
      end
    end
  end

  def complete_2fa_confirmation
    complete_2fa_confirmation_without_entering_otp
    click_submit_default
  end

  def complete_2fa_confirmation_without_entering_otp
    expect(current_path).to eq user_password_confirm_path

    fill_in 'Password', with: Features::SessionHelper::VALID_PASSWORD
    click_button t('forms.buttons.continue')

    expect(current_path).to eq login_two_factor_path(
      otp_delivery_preference: user.otp_delivery_preference
    )
  end

  def update_phone_number(phone = '703-555-0100')
    fill_in 'user_phone_form[phone]', with: phone
    click_button t('forms.buttons.submit.confirm_change')
  end

  def enter_incorrect_otp_code
    fill_in 'code', with: '12345'
    click_submit_default
  end

  def submit_current_password_and_totp
    fill_in 'Password', with: Features::SessionHelper::VALID_PASSWORD
    click_button t('forms.buttons.continue')

    expect(current_path).to eq login_two_factor_authenticator_path

    fill_in 'code', with: generate_totp_code(@secret)
    click_submit_default
  end

  def submit_correct_otp
    click_submit_default
  end

  describe 'attempting to bypass current password entry' do
    it 'does not allow bypassing this step' do
      sign_in_and_2fa_user
      Timecop.travel(Figaro.env.reauthn_window.to_i + 1) do
        visit manage_password_path
        expect(current_path).to eq user_password_confirm_path

        visit login_two_factor_path(otp_delivery_preference: 'sms')

        expect(current_path).to eq user_password_confirm_path
      end
    end
  end
end
