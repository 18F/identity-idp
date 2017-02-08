require 'rails_helper'

feature 'Verify phone' do
  include IdvHelper

  scenario 'phone step redirects to fail after max attempts' do
    sign_in_and_2fa_user
    visit verify_session_path
    fill_out_idv_form_ok
    click_idv_continue
    fill_out_financial_form_ok
    click_idv_continue

    max_attempts_less_one.times do
      fill_out_phone_form_fail
      click_idv_continue

      expect(current_path).to eq verify_phone_path
    end

    fill_out_phone_form_fail
    click_idv_continue
    expect(current_path).to eq verify_fail_path
  end

  scenario 'enter invalid phone number', :js do
    sign_in_and_2fa_user
    visit verify_session_path
    fill_out_idv_form_ok
    click_idv_continue
    fill_out_financial_form_ok
    click_idv_continue

    visit verify_phone_path
    submit_form_with_invalid_phone

    expect(page).to have_content t('errors.messages.improbable_phone')
  end

  def submit_form_with_invalid_phone
    fill_in 'Phone', with: 'five one zero five five five four three two one'
    click_idv_continue
  end
end
