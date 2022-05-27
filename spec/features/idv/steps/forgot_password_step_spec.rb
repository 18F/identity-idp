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

  context 'with idv app feature enabled' do
    before do
      allow(IdentityConfig.store).to receive(:idv_api_enabled_steps).
        and_return(['password_confirm', 'personal_key', 'personal_key_confirm'])
    end

    it 'goes to the forgot password page from the review page' do
      start_idv_from_sp
      complete_idv_steps_before_review_step

      click_link t('idv.forgot_password.link_text')

      expect(page.current_path).to eq(idv_app_forgot_password_path)
    end

    it 'goes back to the review page from the forgot password page' do
      start_idv_from_sp
      complete_idv_steps_before_review_step

      click_link t('idv.forgot_password.link_text')
      click_link t('idv.forgot_password.try_again')

      expect(page.current_path).to eq idv_app_path(step: :password_confirm)
    end

    it 'allows the user to reset their password' do
      start_idv_from_sp
      complete_idv_steps_before_review_step

      click_link t('idv.forgot_password.link_text')
      click_button t('idv.forgot_password.reset_password')

      expect(page).to have_current_path(forgot_password_path, ignore_query: true, wait: 10)

      open_last_email
      click_email_link_matching(/reset_password_token/)

      expect(current_path).to eq edit_user_password_path
    end
  end
end
