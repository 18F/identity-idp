require 'rails_helper'

feature 'setting up a second phone as backup MFA' do
  scenario 'seeing "second phone" as the phone option' do
    create(:user, :unconfirmed)
    confirm_last_user
    fill_in 'password_form_password', with: 'salty pickles'
    click_button t('forms.buttons.continue')

    expect(page).to have_content(t('two_factor_authentication.two_factor_choice_options.phone'))
    expect(page).to have_content(
      t('two_factor_authentication.two_factor_choice_options.phone_info_html'),
    )

    select_2fa_option(:phone)
    fill_in :user_phone_form_phone, with: '2025551234'
    click_send_security_code
    fill_in_code_with_last_phone_otp
    click_submit_default

    click_continue

    expect(page).to have_content(
      t('two_factor_authentication.two_factor_choice_options.second_phone'),
    )
    expect(page).to have_content(
      t(
        'two_factor_authentication.two_factor_choice_options.second_phone_info_html',
        phone: '***-***-1234',
      ),
    )

    select_2fa_option(:phone)
    fill_in :user_phone_form_phone, with: '2025555678'
    click_send_security_code
    fill_in_code_with_last_phone_otp
    click_submit_default

    expect(page).to have_current_path(account_path)
  end
end
