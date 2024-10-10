require 'rails_helper'

RSpec.feature 'Piv recommended after Sign in' do
  let!(:federal_email_domain) { create(:federal_email_domain, name: 'gsa.gov') }

  scenario 'User with valid fed email directed to recommend page and get to setup piv' do
    user = create(:user, :with_phone, { email: 'example@gsa.gov' })

    visit new_user_session_path
    fill_in_credentials_and_submit(user.email, user.password)
    fill_in_code_with_last_phone_otp
    click_submit_default
    expect(page).to have_current_path(login_piv_cac_recommended_path)
    click_button(t('two_factor_authentication.piv_cac_upsell.add_piv'))
    expect(page).to have_current_path(setup_piv_cac_path)
  end

  scenario 'User with mil email directed to recommended PIV page and goes to add piv page' do
    user = create(:user, :with_phone, { email: 'example@army.mil' })

    visit new_user_session_path
    fill_in_credentials_and_submit(user.email, user.password)
    fill_in_code_with_last_phone_otp
    click_submit_default
    expect(page).to have_current_path(login_piv_cac_recommended_path)
    click_button(t('two_factor_authentication.piv_cac_upsell.add_piv'))
    expect(page).to have_current_path(setup_piv_cac_path)
  end

  scenario 'User with fed email and skips recommendation page' do
    user = create(:user, :with_phone, { email: 'example@gsa.gov' })

    visit new_user_session_path
    fill_in_credentials_and_submit(user.email, user.password)
    fill_in_code_with_last_phone_otp
    click_submit_default
    expect(page).to have_current_path(login_piv_cac_recommended_path)
    click_button(t('two_factor_authentication.piv_cac_upsell.skip'))
    expect(page).to have_current_path(account_path)
  end

  scenario 'User with mil email and skips recommendation page' do
    user = create(:user, :with_phone, { email: 'example@army.mil' })

    visit new_user_session_path
    fill_in_credentials_and_submit(user.email, user.password)
    fill_in_code_with_last_phone_otp
    click_submit_default
    expect(page).to have_current_path(login_piv_cac_recommended_path)
    click_button(t('two_factor_authentication.piv_cac_upsell.skip'))
    expect(page).to have_current_path(account_path)
  end

  scenario 'User with invalid .gov email directed to account page' do
    user = create(:user, :with_phone, { email: 'example@bad.gov' })

    visit new_user_session_path
    fill_in_credentials_and_submit(user.email, user.password)
    fill_in_code_with_last_phone_otp
    click_submit_default
    expect(page).to have_current_path(account_path)
  end
end
