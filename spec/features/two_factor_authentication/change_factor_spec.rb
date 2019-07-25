require 'rails_helper'

feature 'Changing authentication factor' do
  describe 'requires re-authenticating' do
    let(:user) { sign_up_and_2fa_loa1_user }

    before do
      user # Sign up the user
      reauthn_date = (Figaro.env.reauthn_window.to_i + 1).seconds.from_now
      Timecop.travel reauthn_date
    end

    after do
      Timecop.return
    end

    scenario 'editing password' do
      visit manage_password_path

      expect(page).to have_content t('help_text.change_factor', factor: 'password')

      complete_2fa_confirmation

      expect(current_path).to eq manage_password_path
    end

    scenario 'waiting too long to change phone number' do
      allow(SmsOtpSenderJob).to receive(:perform_later)

      user = sign_in_and_2fa_user
      old_phone = MfaContext.new(user).phone_configurations.first.phone
      visit manage_phone_path

      Timecop.travel(Figaro.env.reauthn_window.to_i + 1) do
        print page.current_url
        click_link t('forms.two_factor.try_again'), href: manage_phone_path
        complete_2fa_confirmation_without_entering_otp

        expect(SmsOtpSenderJob).to have_received(:perform_later).
          with(
            code: user.reload.direct_otp,
            phone: old_phone,
            otp_created_at: user.reload.direct_otp_sent_at.to_s,
            message: 'jobs.sms_otp_sender_job.login_message',
            locale: nil,
          )

        expect(page).to have_content UserDecorator.new(user).masked_two_factor_phone_number
        expect(page).not_to have_link t('forms.two_factor.try_again')
      end
    end

    context 'resending OTP code to old phone' do
      it 'resends OTP and prompts user to enter their code' do
        allow(SmsOtpSenderJob).to receive(:perform_later)

        user = sign_in_and_2fa_user
        old_phone = MfaContext.new(user).phone_configurations.first.phone

        Timecop.travel(Figaro.env.reauthn_window.to_i + 1) do
          visit manage_phone_path
          complete_2fa_confirmation_without_entering_otp
          click_link t('links.two_factor_authentication.get_another_code')

          expect(SmsOtpSenderJob).to have_received(:perform_later).
            with(
              code: user.reload.direct_otp,
              phone: old_phone,
              otp_created_at: user.reload.direct_otp_sent_at.to_s,
              message: 'jobs.sms_otp_sender_job.login_message',
              locale: nil,
            )

          expect(current_path).
            to eq login_two_factor_path(otp_delivery_preference: 'sms')
        end
      end
    end

    scenario 'deleting account' do
      visit account_delete_path

      expect(page).to have_content t('help_text.no_factor.delete_account')
      complete_2fa_confirmation

      expect(current_path).to eq account_delete_path
    end
  end

  def complete_2fa_confirmation
    complete_2fa_confirmation_without_entering_otp
    fill_in_code_with_last_phone_otp
    click_submit_default
  end

  def complete_2fa_confirmation_without_entering_otp
    expect(current_path).to eq user_password_confirm_path

    fill_in 'Password', with: Features::SessionHelper::VALID_PASSWORD
    click_button t('forms.buttons.continue')

    expect(current_path).to eq login_two_factor_path(
      otp_delivery_preference: user.otp_delivery_preference,
    )
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
    fill_in_code_with_last_phone_otp
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
