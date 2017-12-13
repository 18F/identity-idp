require 'rails_helper'

feature 'IdV max attempts' do
  include IdvHelper

  scenario 'profile shows failure modal after max attempts', :email, :idv_job, :js do
    sign_in_and_2fa_user
    visit verify_session_path

    max_attempts_less_one.times do
      fill_out_idv_form_fail
      click_idv_continue
      click_button t('idv.modal.button.warning')

      expect(current_path).to eq verify_session_result_path
    end

    fill_out_idv_form_fail
    click_idv_continue

    expect(page).to have_css('.modal-fail', text: t('idv.modal.sessions.heading'))
  end

  scenario 'phone shows failure modal after max attempts', :email, :idv_job, :js do
    sign_in_and_2fa_user
    visit verify_session_path
    fill_out_idv_form_ok
    click_idv_continue
    click_idv_address_choose_phone

    max_attempts_less_one.times do
      fill_out_phone_form_fail
      click_idv_continue
      click_button t('idv.modal.button.warning')

      expect(current_path).to eq verify_phone_result_path
    end

    fill_out_phone_form_fail
    click_idv_continue

    expect(page).to have_css('.modal-fail', text: t('idv.modal.phone.heading'))
  end
end
