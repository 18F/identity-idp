feature 'RegistrationsEnabled', devise: true do
  describe 'When registrations are disabled' do
    scenario 'user cannot create an account' do
      allow(AppSetting).to(receive(:registrations_enabled?)).and_return(false)

      visit root_path

      expect(page).to(have_selector("input[type=submit][value='Not accepting new accounts']"))
    end
  end

  describe 'When registrations are enabled' do
    scenario 'user can create an account' do
      allow(AppSetting).to(receive(:registrations_enabled?)).and_return(true)

      visit root_path

      expect(page).not_to(have_selector("input[type=submit][value='Not accepting new accounts']"))
      expect(page).to(have_content('Create a new account'))
    end
  end
end
