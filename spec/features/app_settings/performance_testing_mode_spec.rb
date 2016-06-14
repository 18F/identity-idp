require 'rails_helper'

# Feature Management: pt_mode?
# when true: any OTP can be entered
# when false: only randomly-generated OTP can be entered

feature 'Performance Testing Mode', devise: true do
  let(:user) { create(:user, :signed_up) }

  describe 'Any old OTP is not allowed' do
    before do
      allow(FeatureManagement).to(receive(:pt_mode?)).and_return(false)
    end

    scenario 'does not allow user to enter any old OTP during login' do
      sign_in_user(user)
      fill_in 'code', with: '12345678'
      click_button 'Submit'
      expect(current_path).to eq user_two_factor_authentication_path
    end

    scenario 'allows user to enter their unique OTP during login' do
      sign_in_user(user)
      fill_in 'code', with: user.reload.direct_otp
      click_button 'Submit'
      expect(current_path).to eq dashboard_index_path
    end

    scenario 'a site-wide banner is not displayed' do
      sign_in_user(user)
      expect(page).not_to have_content('Performance Testing Mode')
    end
  end

  describe 'Any old OTP is allowed' do
    before do
      allow(FeatureManagement).to(receive(:pt_mode?)).and_return(true)
    end

    scenario 'allows user to enter any OTP' do
      sign_in_user(user)
      fill_in 'code', with: '12345678'
      click_button 'Submit'
      expect(current_path).to eq dashboard_index_path
    end

    scenario 'a site-wide banner is displayed' do
      sign_in_user(user)
      expect(page).to have_content('OTPs are not secure.')
    end
  end
end
