require 'rails_helper'

RSpec.feature 'Password recovery via personal key for a GPO-verified user' do
  include IdvStepHelper

  let(:user) { create(:user, :fully_registered) }
  let(:new_password) { 'some really awesome new password' }

  before do
    allow(FeatureManagement).to receive(:reveal_gpo_code?).and_return(true)
  end

  scenario 'lets them reactivate their profile with their personal key', email: true, js: true do
    complete_idv_steps_with_gpo_before_confirmation_step(user)
    click_on t('doc_auth.buttons.continue')

    click_on t('account.index.verification.reactivate_button')
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

    expect(current_path).to eq verify_personal_key_path
    fill_in 'personal_key', with: personal_key
    click_continue

    expect(current_path).to eq verify_password_path
    fill_in 'Password', with: new_password
    click_continue

    expect(page).to have_content t('idv.messages.personal_key')
    expect(page).to have_content t('headings.account.verified_account')
  end
end
