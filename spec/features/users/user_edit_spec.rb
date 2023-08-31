require 'rails_helper'

RSpec.feature 'User edit' do
  let(:user) { create(:user, :fully_registered) }

  context 'editing password' do
    before do
      sign_in_and_2fa_user(user)
      visit manage_password_path
    end

    scenario 'user sees error message if form is submitted with invalid password' do
      fill_in 'New password', with: 'foo'
      click_button 'Update'

      expect(page).to have_css '.usa-alert', text: 'Please review the problems below:'
      expect(page).
        to have_content t(
          'errors.attributes.password.too_short.other',
          count: Devise.password_length.first,
        )
    end
  end
end
