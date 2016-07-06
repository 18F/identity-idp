require 'rails_helper'

# Feature: User profile
#   As a user
#   I want to interact with my user info
feature 'User profile' do
  context 'user clicks the delete account button' do
    it 'deletes the account and signs the user out with a flash message' do
      sign_in_and_2fa_user
      visit profile_index_path
      click_button t('forms.buttons.delete_account')

      expect(page).to have_content t('devise.registrations.destroyed')
      expect(current_path).to eq root_path
      expect(User.count).to eq 0
    end
  end
end
