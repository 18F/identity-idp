require 'rails_helper'

feature 'forgot password step', :js do
  include IdvStepHelper

  it 'goes to the forgot password page from the review page' do
    start_idv_from_sp
    complete_idv_steps_before_review_step

    click_link t('idv.forgot_password.link_text')

    expect(page.current_path).to eq(idv_forgot_password_path)
  end

  it 'goes back to the review page from the forgot password page' do
    start_idv_from_sp
    complete_idv_steps_before_review_step

    click_link t('idv.forgot_password.link_text')
    click_link t('idv.forgot_password.try_again')

    expect(page.current_path).to eq(idv_review_path)
  end

  it 'allows the user to reset their password' do
    start_idv_from_sp
    complete_idv_steps_before_review_step

    click_link t('idv.forgot_password.link_text')
    click_button t('idv.forgot_password.reset_password')

    expect(page.current_path).to eq(forgot_password_path)

    open_last_email
    click_email_link_matching(/reset_password_token/)

    expect(current_path).to eq edit_user_password_path
  end
end
