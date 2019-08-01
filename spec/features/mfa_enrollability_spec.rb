require 'rails_helper'

describe 'MFA enrollability' do
  let(:user) { create(:user, :signed_up, :with_authentication_app) }

  it 'does not allow choosing totp as backup auth method after it is used as primary' do
    sign_up_and_set_password

    select_2fa_option('auth_app')
    secret = find('#qr-code').text
    fill_in 'code', with: generate_totp_code(secret)
    click_button 'Submit'

    click_continue

    expect(page).to have_selector('#two_factor_options_form_selection_auth_app', count: 0)
    expect(page).to have_selector('#two_factor_options_form_selection_phone', count: 1)
  end
end
