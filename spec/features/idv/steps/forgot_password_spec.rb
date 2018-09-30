require 'rails_helper'

feature 'idv forgot password' do
  include IdvStepHelper

  it 'allows you to go to the forgot password page from the review page' do
    start_idv_from_sp
    complete_idv_steps_before_review_step
    click_link(t('idv.forgot_password.link_text'))

    expect(current_path).to eq idv_forgot_password_path
  end

  it 'allows you to go back to the review page from the forgot password page' do
    start_idv_from_sp
    complete_idv_steps_before_review_step
    click_link(t('idv.forgot_password.link_text'))
    click_link(t('idv.forgot_password.try_again'))

    expect(current_path).to eq idv_review_path
  end

  it 'allows you to reset your password' do
    start_idv_from_sp
    complete_idv_steps_before_review_step
    click_link(t('idv.forgot_password.link_text'))
    click_button(t('idv.forgot_password.reset_password'))

    expect(current_path).to eq forgot_password_path
  end
end
