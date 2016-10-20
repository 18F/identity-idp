require 'rails_helper'

feature 'Contact us' do
  scenario 'user submits contact form with non-empty email / phone' do
    visit contact_path

    fill_in 'contact_form_email_or_tel', with: 'foo@bar.com'
    click_button t('forms.buttons.send')

    expect(page).to have_content t('contact.messages.thanks')
  end

  scenario 'user submits contact form with no email / phone' do
    visit contact_path

    fill_in 'contact_form_email_or_tel', with: ''
    click_button t('forms.buttons.send')

    expect(page).to have_content t('simple_form.error_notification.default_message')
  end
end
