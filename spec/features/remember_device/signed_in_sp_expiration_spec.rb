require 'rails_helper'

RSpec.feature 'SP expiration while signed in' do
  include SamlAuthHelper

  ##
  # This test is a regression spec for a specific bug in `remember_device_expired_for_sp?`
  #
  # See https://github.com/18F/identity-idp/pull/9458
  #
  scenario 'signed in user with expired remember device does not get stuck in MFA loop' do
    user = sign_up_and_set_password
    user.password = Features::SessionHelper::VALID_PASSWORD

    select_2fa_option('phone')
    fill_in :new_phone_form_phone, with: '2025551212'
    click_send_one_time_code
    check t('forms.messages.remember_device')
    fill_in_code_with_last_phone_otp
    click_submit_default
    skip_second_mfa_prompt

    first(:button, t('links.sign_out')).click

    sign_in_user(user)

    travel_to(5.seconds.from_now) do
      visit_idp_from_sp_with_ial1_aal2(:oidc)

      expect(current_path).to eq(login_two_factor_path(otp_delivery_preference: :sms))
      expect(page).to have_content(t('two_factor_authentication.header_text'))

      fill_in_code_with_last_phone_otp
      uncheck t('forms.messages.remember_device')
      click_submit_default

      expect(page).to have_current_path(sign_up_completed_path)
    end
  end
end
