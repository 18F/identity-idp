feature 'Confirmations', devise: true do
  describe 'When the user is not logged in and confirmation_token is falsey/empty' do
    scenario 'user cannot access users/confirmations' do
      visit user_confirmation_path

      expect(page).to have_content("Confirmation token can't be blank")
    end

    scenario 'user cannot submit a blank confirmation token' do
      visit "#{user_confirmation_path}?confirmation_token="

      expect(page).to have_content("Confirmation token can't be blank")
    end

    scenario 'user cannot submit an empty single-quoted string as a token' do
      visit "#{user_confirmation_path}?confirmation_token=''"

      expect(page).to have_content('Confirmation token is invalid')
    end

    scenario 'user cannot submit an empty double-quoted string as a token' do
      visit "#{user_confirmation_path}?confirmation_token=%22%22"

      expect(page).to have_content('Confirmation token is invalid')
    end
  end
end
