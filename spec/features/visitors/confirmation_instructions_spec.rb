require 'rails_helper'
require 'email_spec'

# Feature: Confirmation Instructions
#   As a user
#   I want to resend my confirmation instructions
#   So I can confirm my account and gain access to the site
feature 'Confirmation Instructions', devise: true do
  include(EmailSpec::Helpers)
  include(EmailSpec::Matchers)

  let!(:user) { FactoryGirl.build(:user, confirmed_at: nil) }

  before(:each) do
    visit new_user_confirmation_path
  end

  # Scenario: User can request confirmation instructions be sent to them
  #   Given I do not confirm my account in time
  #   When I complete the form on the resend confirmation instructions page
  #   Then I receive an email
  scenario 'user can resend their confirmation instructions via email' do
    user.save!
    fill_in 'Email', with: user.email

    click_button 'Resend confirmation instructions'
    expect(unread_emails_for(user.email)).to be_present
  end

  # Scenario: User is unable to determine if someone else's account exists
  #   Given I want to find out if an account exists for no_account_exists@example.com
  #   When I complete the form on the resend confirmation instructions page
  #   Then I still don't know if an account exists
  scenario 'user is unable to determine if account exists' do
    fill_in 'Email', with: 'no_account_exists@example.com'
    click_button 'Resend confirmation instructions'
    expect(page).to have_content t('devise.confirmations.send_paranoid_instructions')
  end

  # Scenario: User must enter a valid email address
  #   Given I am phising for accounts
  #   When I enter invalid email addresses
  #   Then I receive an error
  scenario 'user enters email with invalid format' do
    invalid_addresses = [
      'user@domain-without-suffix',
      'Buy Medz 0nl!ne http://pharma342.onlinestore.com'
    ]
    allow(ValidateEmail).to receive(:mx_valid?).and_return(false)

    invalid_addresses.each do |email|
      fill_in 'Email', with: email
      click_button 'Resend confirmation instructions'

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
      click_button 'Resend confirmation instructions'

      expect(page).to have_content t('valid_email.validations.email.invalid')
    end
  end

  scenario 'user enters empty email with JS turned on', js: true do
    fill_in 'Email', with: ''
    click_button 'Resend confirmation instructions'

    expect(page).to have_content 'Please fill in all required fields'
  end

  scenario 'user enters empty email' do
    fill_in 'Email', with: ''
    click_button 'Resend confirmation instructions'

    expect(page).to have_content t('valid_email.validations.email.invalid')
  end

  scenario 'confirmations new page has localized title' do
    expect(page).to have_title t('upaya.titles.confirmations.new', app_name: APP_NAME)
  end

  scenario 'confirmations new page has localized heading' do
    expect(page).to have_title t('upaya.headings.confirmations.new', app_name: APP_NAME)
  end
end
