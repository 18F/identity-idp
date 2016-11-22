require 'rails_helper'
require 'axe/rspec'

feature 'Accessibility on all pages', :js do
  scenario 'contact page' do
    visit contact_path

    expect(page).to be_accessible
  end

  pending 'login / root path' do
    visit root_path

    expect(page).to be_accessible
  end

  scenario 'new user start registration page' do
    visit new_user_start_path

    expect(page).to be_accessible
  end

  scenario 'new user registration page' do
    visit new_user_registration_path

    expect(page).to be_accessible
  end

  scenario 'user registration page' do
    email = 'test@example.com'
    sign_up_with(email)

    expect(page).to be_accessible
  end

  scenario 'user confirmation page' do
    email = 'test@example.com'
    sign_up_with(email)
    open_email(email)
    visit_in_email(t('mailer.confirmation_instructions.link_text'))

    expect(page).to be_accessible
  end

  pending 'phone 2fa setup page' do
    sign_up_and_set_password

    expect(page).to be_accessible
  end

  scenario 'enter 2fa phone OTP code page' do
    sign_up_and_set_password
    fill_in 'Phone', with: '555-555-5555'
    click_button t('forms.buttons.send_passcode')

    expect(page).to be_accessible
  end

  scenario 'recovery code page' do
    sign_up_and_set_password
    fill_in 'Phone', with: '555-555-5555'
    click_button t('forms.buttons.send_passcode')
    click_button t('forms.buttons.submit.default') # enter 2FA code

    expect(page).to be_accessible
  end

  pending 'profile page' do
    sign_in_and_2fa_user

    visit profile_path

    expect(page).to be_accessible
  end

  pending 'edit email page' do
    sign_in_and_2fa_user

    visit '/edit/email'

    expect(page).to be_accessible
  end

  pending 'edit password page' do
    sign_in_and_2fa_user

    visit '/settings/password'

    expect(page).to be_accessible
  end

  pending 'edit phone page' do
    sign_in_and_2fa_user

    visit '/edit/phone'

    expect(page).to be_accessible
  end

  pending 'generate new recovery code page' do
    sign_in_and_2fa_user

    visit '/settings/recovery-code'

    expect(page).to be_accessible
  end

  pending 'start set up of authenticator app page' do
    sign_in_and_2fa_user

    visit '/authenticator_start'

    expect(page).to be_accessible
  end

  pending 'set up authenticator app page' do
    sign_in_and_2fa_user

    visit '/authenticator_setup'

    expect(page).to be_accessible
  end
end
