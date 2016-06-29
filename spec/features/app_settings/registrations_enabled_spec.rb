require 'rails_helper'

feature 'RegistrationsEnabled', devise: true do
  context 'When registrations are disabled' do
    it 'prevents users from visiting sign up page' do
      allow(AppSetting).to(receive(:registrations_enabled?)).and_return(false)

      visit new_user_registration_path

      expect(page.current_url).to eq(root_url)
    end
  end

  context 'When registrations are enabled' do
    it 'allows user to visit the sign up page' do
      allow(AppSetting).to(receive(:registrations_enabled?)).and_return(true)

      visit new_user_registration_path

      expect(page.current_url).to eq(new_user_registration_url)
    end
  end
end
