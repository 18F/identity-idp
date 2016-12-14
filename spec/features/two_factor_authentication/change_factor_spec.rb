require 'rails_helper'

feature 'Changing authentication factor' do
  describe 'requires re-authenticating' do
    let!(:user) { sign_up_and_2fa }

    scenario 'editing password' do
      visit manage_password_path
      complete_2fa_confirmation

      expect(current_path).to eq manage_password_path
    end

    scenario 'editing phone number' do
      allow(SmsSenderNumberChangeJob).to receive(:perform_later)

      @previous_phone_confirmed_at = user.reload.phone_confirmed_at

      visit manage_phone_path
      complete_2fa_confirmation

      update_phone_number_and_choose_sms_delivery

      expect(page).to have_link t('forms.two_factor.try_again'), href: manage_phone_path

      enter_incorrect_otp_code

      expect(page).to have_content t('devise.two_factor_authentication.invalid_otp')
      expect(user.reload.phone).to_not eq '+1 (703) 555-0100'
      expect(page).to have_link t('forms.two_factor.try_again'), href: manage_phone_path

      enter_correct_otp_code_for_user(user)

      expect(page).to have_content t('notices.phone_confirmation_successful')
      expect(current_path).to eq profile_path
      expect(SmsSenderNumberChangeJob).to have_received(:perform_later).with('+1 (202) 555-1212')
      expect(user.reload.phone).to eq '+1 (703) 555-0100'
      expect(user.reload.phone_confirmed_at).to_not eq(@previous_phone_confirmed_at)

      visit login_two_factor_path(delivery_method: 'sms')
      expect(current_path).to eq profile_path
    end

    scenario 'waiting too long to change phone number' do
      allow(SmsOtpSenderJob).to receive(:perform_later)

      user = sign_in_and_2fa_user
      old_phone = user.phone
      visit manage_phone_path
      update_phone_number_and_choose_sms_delivery
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
      end
    end

    scenario 'editing email' do
      visit manage_email_path
      complete_2fa_confirmation

      expect(current_path).to eq manage_email_path
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

    expect(current_path).to eq user_two_factor_authentication_path

    click_submit_default

    expect(current_path).to eq login_two_factor_path(delivery_method: 'sms')
  end

  def update_phone_number_and_choose_sms_delivery
    fill_in 'update_user_phone_form[phone]', with: '703-555-0100'
    click_button t('forms.buttons.submit.update')
    click_submit_default
  end

  def enter_incorrect_otp_code
    fill_in 'code', with: '12345'
    click_submit_default
  end
end
