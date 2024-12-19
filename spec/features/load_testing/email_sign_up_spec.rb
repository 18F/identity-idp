require 'rails_helper'

RSpec.feature 'Email sign up' do
  scenario 'Load testing feature is on' do
    allow(IdentityConfig.store).to receive(:enable_load_testing_mode).and_return(true)
    email = 'test@example.com'

    sign_up_with(email)
    click_link('CONFIRM NOW')

    expect(page).to have_current_path(sign_up_enter_password_path, ignore_query: true)
    expect(page).to have_content t('devise.confirmations.confirmed_but_must_set_password')
  end
end
