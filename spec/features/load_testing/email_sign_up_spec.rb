require 'rails_helper'

feature 'Email sign up' do
  scenario 'Load testing feature is on' do
    allow(Figaro.env).to receive(:enable_load_testing_mode).and_return('true')
    email = 'test@example.com'

    sign_up_with(email)
    click_link('CONFIRM NOW')

    expect(current_path).to eq sign_up_enter_password_path
    expect(page).to have_content t('devise.confirmations.confirmed_but_must_set_password')
  end
end
