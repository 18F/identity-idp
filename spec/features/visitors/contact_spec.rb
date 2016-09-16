require 'rails_helper'

# Feature: Contact us
#   As a visitor
#   I want to fill out and submit contact form
feature 'Contact us' do
  # Scenario: User submits filled-in contact form
  #   When I fill in form and click submit
  #   Then I get success message
  scenario 'user submits contact form with non-empty email / phone' do
    visit contact_path

    fill_in 'contact_form_email_or_tel', with: 'foo@bar.com'
    click_button t('forms.buttons.send')

    expect(page).to have_content t('contact.messages.thanks')
  end

  # Scenario: User cannot submit contact without adding email or phone
  #   When I leave the email / phone field empty and click submit
  #   Then I receive a useful error
  scenario 'user submits contact form with no email / phone' do
    visit contact_path

    fill_in 'contact_form_email_or_tel', with: ''
    click_button t('forms.buttons.send')

    expect(page).to have_content t('simple_form.error_notification.default_message')
  end
end
