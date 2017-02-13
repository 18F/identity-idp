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
    expect(page).to have_css('.alert-error', text: t('idv.modal.phone.heading'))
  end

  context 'Idv phone and user phone are different' do
    scenario 'prompts to confirm phone' do
      user = create(
        :user, :signed_up,
        phone: '+1 (416) 555-0190',
        password: Features::SessionHelper::VALID_PASSWORD
      )
      sign_in_and_2fa_user(user)
      visit verify_session_path

      complete_idv_profile_with_phone('555-555-0000')

      expect(page).to have_link t('forms.two_factor.try_again'), href: verify_phone_path

      enter_correct_otp_code_for_user(user)
      click_acknowledge_recovery_code

      expect(current_path).to eq profile_path
    end
  end

  scenario 'phone field only allows numbers', js: true do
    sign_in_and_2fa_user
    visit verify_session_path
    fill_out_idv_form_ok
    click_idv_continue
    fill_out_financial_form_ok
    click_idv_continue

    visit verify_phone_path
    fill_in 'Phone', with: ''
    find('#idv_phone_form_phone').native.send_keys('abcd1234')

    expect(find('#idv_phone_form_phone').value).to eq '1 (234) '
  end

  def complete_idv_profile_with_phone(phone)
    fill_out_idv_form_ok
    click_button t('forms.buttons.continue')
    fill_out_financial_form_ok
    click_button t('forms.buttons.continue')
    fill_out_phone_form_ok(phone)
    click_button t('forms.buttons.continue')
    fill_in :user_password, with: user_password
    click_submit_default
    # choose default SMS delivery method for confirming this new number
    click_submit_default
  end
end
