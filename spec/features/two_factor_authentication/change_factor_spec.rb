require 'rails_helper'

RSpec.feature 'Changing authentication factor' do
  describe 'requires re-authenticating' do
    let(:user) { sign_up_and_2fa_ial1_user }

    before do
      user # Sign up the user
      expire_reauthn_window
    end

    scenario 'editing password' do
      visit manage_password_path

      expect(page).to have_current_path login_two_factor_options_path

      complete_2fa_confirmation

      expect(page).to have_current_path manage_password_path
    end

    context 'resending OTP code to old phone' do
      it 'resends OTP and prompts user to enter their code' do
        allow(Telephony).to receive(:send_authentication_otp).and_call_original

        user = sign_in_and_2fa_user
        phone_configuration = MfaContext.new(user).phone_configurations.first
        old_phone = phone_configuration.phone
        parsed_phone = Phonelib.parse(old_phone)

        expire_reauthn_window
        visit manage_phone_path(id: phone_configuration)
        complete_2fa_confirmation_without_entering_otp
        click_link t('links.two_factor_authentication.send_another_code')

        expect(Telephony).to have_received(:send_authentication_otp).with(
          otp: user.reload.direct_otp,
          to: old_phone,
          expiration: 10,
          channel: :sms,
          otp_format: 'digit',
          domain: IdentityConfig.store.domain_name,
          country_code: 'US',
          extra_metadata: {
            area_code: parsed_phone.area_code,
            phone_fingerprint: Pii::Fingerprinter.fingerprint(parsed_phone.e164),
            resend: 'true',
          },
        ).once

        expect(page).to have_current_path(
          login_two_factor_path(otp_delivery_preference: 'sms'),
        )
      end
    end

    context 'changing authentication methods' do
      it 'returns user to account page if they choose to cancel' do
        sign_in_and_2fa_user
        expire_reauthn_window
        visit manage_password_path
        complete_2fa_confirmation_without_entering_otp

        # Canceling from MFA prompt
        click_on t('links.cancel')
        expect(page).to have_current_path account_path

        # Canceling from MFA selection
        visit manage_password_path
        complete_2fa_confirmation_without_entering_otp
        click_on t('two_factor_authentication.login_options_link_text')
        click_on t('links.cancel')
        expect(page).to have_current_path account_path
      end
    end
  end

  context 'when logged in at AAL1' do
    it 'requires 2FA authentication to manage 2FA configurations' do
      user = user_with_2fa
      sign_in_with_warden(user, auth_method: 'remember_device')

      # Ensure reauthentication context does not prompt incorrectly
      visit webauthn_setup_path
      expect(page).to have_current_path login_two_factor_options_path

      visit phone_setup_path
      expect(page).to have_current_path login_two_factor_options_path

      find("label[for='two_factor_options_form_selection_sms']").click
      click_on t('forms.buttons.continue')
      fill_in_code_with_last_phone_otp
      click_submit_default
      expect(page).to have_current_path phone_setup_path

      visit phone_setup_path
      expect(page).to have_current_path phone_setup_path
    end
  end

  def complete_2fa_confirmation
    complete_2fa_confirmation_without_entering_otp
    fill_in_code_with_last_phone_otp
    click_submit_default
  end

  def complete_2fa_confirmation_without_entering_otp
    expect(page).to have_current_path login_two_factor_options_path

    find("label[for='two_factor_options_form_selection_sms']").click
    click_on t('forms.buttons.continue')

    expect(page).to have_current_path login_two_factor_path(
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

    expect(page).to have_current_path login_two_factor_authenticator_path

    fill_in 'code', with: generate_totp_code(@secret)
    click_submit_default
  end

  def submit_correct_otp
    fill_in_code_with_last_phone_otp
    click_submit_default
  end
end
