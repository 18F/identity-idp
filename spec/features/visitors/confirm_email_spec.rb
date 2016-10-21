require 'rails_helper'

feature 'Confirm email' do
  scenario 'confirms valid email and sets valid password' do
    sign_up_with('test@example.com')
    confirm_last_user

    expect(page).to have_content t('devise.confirmations.confirmed_but_must_set_password')
    expect(page).to have_title t('titles.confirmations.show')
    expect(page).to have_content t('forms.confirmation.show_hdr')

    fill_in 'password_form_password', with: Features::SessionHelper::VALID_PASSWORD
    click_button t('forms.buttons.submit.default')

    expect(current_url).to eq phone_setup_url
    expect(page).to_not have_content t('devise.confirmations.confirmed_but_must_set_password')
  end

  scenario 'it sets reset_requested_at to nil after password confirmation' do
    user = sign_up_and_set_password

    expect(user.reset_requested_at).to be_nil
  end
end
