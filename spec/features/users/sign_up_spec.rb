require 'rails_helper'

feature 'Sign Up' do
  context 'confirmation token error message does not persist on success' do
    scenario 'with no or invalid token' do
      visit sign_up_create_email_confirmation_url(confirmation_token: '')
      expect(page).to have_content t('errors.messages.confirmation_invalid_token')

      sign_up

      expect(page).not_to have_content t('errors.messages.confirmation_invalid_token')
    end
  end
end
