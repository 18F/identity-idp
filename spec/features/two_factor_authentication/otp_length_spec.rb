# checks length of OTP against configuration

feature 'OTP length', devise: true do
  describe 'Devise configuration sets otp length' do
    scenario "otp length matches configuration (#{Devise.otp_length || 6})" do
      user = create(:user, :signed_up)

      sign_in_user(user)

      expect(user.otp_code.length).to eq(Devise.otp_length || 6)

      fill_in 'code', with: user.otp_code
      click_button 'Submit'
      user.reload

      expect(user.second_factor_attempts_count).to equal(0)
    end
  end
end # feature 'configurable OTP length'
