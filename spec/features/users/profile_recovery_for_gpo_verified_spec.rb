require 'rails_helper'

RSpec.feature 'Password recovery via personal key for a GPO-verified user' do
  include IdvStepHelper

  let(:new_password) { 'some really awesome new password' }

  scenario 'lets them reactivate their profile with their personal key', email: true do
    user = create(:user, :fully_registered, :with_pending_gpo_profile)
    visit new_user_session_path
    fill_in_credentials_and_submit(user.email, user.password)
    fill_in I18n.t('components.one_time_code_input.label'), with: last_phone_otp
    click_submit_default

    fill_in 'gpo_verify_form_otp', with: 'ABCDE12345'
    click_on t('idv.gpo.form.submit')

    personal_key = scrape_personal_key
    check t('forms.personal_key.required_checkbox')
    click_continue

    click_on t('links.sign_out')

    trigger_reset_password_and_click_email_link(user.email)
    reset_password_and_sign_back_in(user, new_password)
    fill_in_code_with_last_phone_otp
    click_submit_default

    click_on t('links.account.reactivate.with_key')

    expect(page).to have_current_path verify_personal_key_path
    fill_in 'personal_key', with: personal_key
    click_continue

    expect(page).to have_current_path verify_password_path
    fill_in 'Password', with: new_password
    click_continue

    expect(page).to have_content(t('forms.personal_key_partial.header'))
    expect(page).to have_current_path(manage_personal_key_path)

    personal_key = PersonalKeyGenerator.new(user).normalize(scrape_personal_key)

    expect(user.reload.valid_personal_key?(personal_key)).to eq(true)
  end
end
