require 'rails_helper'

feature 'User edit' do
  context 'editing email' do
    before do
      sign_in_and_2fa_user
      visit manage_email_path
    end

    scenario 'user sees error message if form is submitted without email', :js, idv_job: true do
      fill_in 'Email', with: ''
      click_button 'Update'

      expect(page).to have_content t('valid_email.validations.email.invalid')
    end
  end

  context 'editing 2FA phone number' do
    before do
      sign_in_and_2fa_user
      visit manage_phone_path
    end

    scenario 'user sees error message if form is submitted without phone number', js: true do
      fill_in 'Phone', with: ''
      click_button t('forms.buttons.submit.confirm_change')

      expect(page).to have_content t('errors.messages.improbable_phone')
    end

    scenario 'updates international code as user types', :js do
      fill_in 'Phone', with: '+81 54 354 3643'

      expect(page.find('#update_user_phone_form_international_code').value).to eq 'JP'

      fill_in 'Phone', with: '5376'
      select 'Morocco +212', from: 'International code'

      expect(find('#update_user_phone_form_phone').value).to eq '+212 5376'

      fill_in 'Phone', with: '54354'
      select 'Japan +81', from: 'International code'

      expect(find('#update_user_phone_form_phone').value).to include '+81'
    end
  end
end
