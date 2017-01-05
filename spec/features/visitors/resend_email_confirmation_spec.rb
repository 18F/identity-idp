require 'rails_helper'
require 'email_spec'

feature 'Visit requests confirmation instructions again during sign up' do
  include(EmailSpec::Helpers)
  include(EmailSpec::Matchers)

  let!(:user) { build(:user, confirmed_at: nil) }

  before(:each) do
    visit sign_up_email_resend_path
  end

  scenario 'user can resend their confirmation instructions via email' do
    user.save!
    fill_in 'Email', with: user.email

    click_button t('forms.buttons.resend_confirmation')
    expect(unread_emails_for(user.email)).to be_present
  end

  scenario 'user enters email with invalid format' do
    invalid_addresses = [
      'user@domain-without-suffix',
      'Buy Medz 0nl!ne http://pharma342.onlinestore.com'
    ]
    allow(ValidateEmail).to receive(:mx_valid?).and_return(false)

    invalid_addresses.each do |email|
      fill_in 'Email', with: email
      click_button t('forms.buttons.resend_confirmation')

      expect(page).to have_content t('valid_email.validations.email.invalid')
    end
  end

  scenario 'user enters email with invalid domain name' do
    invalid_addresses = [
      'foo@bar.com',
      'foo@example.com'
    ]
    allow(ValidateEmail).to receive(:mx_valid?).and_return(false)

    invalid_addresses.each do |email|
      fill_in 'Email', with: email
      click_button t('forms.buttons.resend_confirmation')

      expect(page).to have_content t('valid_email.validations.email.invalid')
    end
  end

  scenario 'user enters empty email' do
    fill_in 'Email', with: ''
    click_button t('forms.buttons.resend_confirmation')

    expect(page).to have_content t('valid_email.validations.email.invalid')
  end
end
