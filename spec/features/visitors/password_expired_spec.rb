# Feature: Password Expiration
#   As a user
#   I want to update my password when it expires after 1 year
#   So I can regain access to protected areas of the site
feature 'Password Expiration', devise: true do
  context 'when password has not expired yet' do
    it 'prompts user to enter OTP code' do
      user = create(:user, :signed_up)
      sign_in_user(user)

      expect(page).to have_content 'Enter your one-time passcode'
    end

    it 'redirects to root when password_expired is visited directly' do
      user = create(:user, :signed_up)
      sign_in_and_2fa_user(user)
      visit user_password_expired_path

      expect(current_path).to eq dashboard_index_path
    end
  end

  context 'when password has expired' do
    before do
      @user = create(:user, :signed_up)
      Timecop.travel(570_000.minutes)
      sign_in_user(@user)
    end

    after do
      Timecop.return
    end

    it 'prompts user to update their password' do
      expect(page).to have_content 'Your password is expired'
      expect(page).to_not have_content 'Enter your one-time passcode'
    end

    context 'when password update is valid' do
      it 'changes the password with success notice, and prompts for 2FA' do
        previous_password = @user.encrypted_password

        fill_in 'Current password', with: @user.password
        fill_in 'New password', with: 'Val!dPassw0rd'
        fill_in 'Confirm your new password', with: 'Val!dPassw0rd'
        click_button 'Change my password'

        expect(current_path).to eq user_two_factor_authentication_path
        expect(page).to have_content 'Your new password is saved.'
        expect(@user.reload.encrypted_password).to_not eq previous_password
      end
    end

    it 'requires current password' do
      fill_in 'Current password', with: ''
      fill_in 'New password', with: 'Val!dPassw0rd'
      fill_in 'Confirm your new password', with: 'Val!dPassw0rd'
      click_button 'Change my password'

      expect(current_path).to eq user_password_expired_path
      expect(page).to have_content "can't be blank"
    end

    it 'requires current password to be valid' do
      fill_in 'Current password', with: 'wrong_password'
      fill_in 'New password', with: 'Val!dPassw0rd'
      fill_in 'Confirm your new password', with: 'Val!dPassw0rd'
      click_button 'Change my password'

      expect(current_path).to eq user_password_expired_path
      expect(page).to have_content
      t('activerecord.errors.models.user.attributes.current_password.invalid')
    end

    it 'requires new password' do
      fill_in 'Current password', with: @user.password
      fill_in 'New password', with: ''
      fill_in 'Confirm your new password', with: 'Val!dPassw0rd'
      click_button 'Change my password'

      expect(current_path).to eq user_password_expired_path
      expect(page).to have_content "can't be blank"
    end

    it 'does not let user in with just current password' do
      fill_in 'Current password', with: @user.password
      fill_in 'New password', with: ''
      fill_in 'Confirm your new password', with: ''
      click_button 'Change my password'

      expect(current_path).to eq user_password_expired_path
      expect(page).to have_content "can't be blank"
    end

    it 'requires password confirmation' do
      fill_in 'Current password', with: @user.password
      fill_in 'New password', with: 'Val!dPassw0rd'
      fill_in 'Confirm your new password', with: ''
      click_button 'Change my password'

      expect(current_path).to eq user_password_expired_path
      expect(page).to have_content 'does not match password'
    end

    it 'requires new password to be different from previous one' do
      old_password = @user.password
      fill_in 'Current password', with: old_password
      fill_in 'New password', with: 'Val!dPassw0rd'
      fill_in 'Confirm your new password', with: 'Val!dPassw0rd'
      click_button 'Change my password'
      click_link(t('upaya.headings.log_out'), match: :first)
      @user.reload.update(password_changed_at: Time.current - 570_000.minutes)
      signin(@user.email, 'Val!dPassw0rd')
      fill_in 'Current password', with: 'Val!dPassw0rd'
      fill_in 'New password', with: old_password
      fill_in 'Confirm your new password', with: old_password
      click_button 'Change my password'

      expect(current_path).to eq user_password_expired_path
      expect(page).to have_content 'was already taken in the past!'
    end

    it 'displays an error if all required fields are empty and JS is on', js: true do
      click_button 'Change my password'

      expect(page).to have_content 'Please fill in all required fields'
    end

    it 'displays an error if current password is empty and JS is on', js: true do
      fill_in 'New password', with: 'Val!dPassw0rd'
      fill_in 'Confirm your new password', with: 'Val!dPassw0rd'
      click_button 'Change my password'

      expect(page).to have_content 'Please fill in all required fields'
    end

    it 'displays an error if new password is empty and JS is on', js: true do
      fill_in 'Current password', with: @user.password
      fill_in 'New password', with: ''
      fill_in 'Confirm your new password', with: 'Val!dPassw0rd'
      click_button 'Change my password'

      expect(page).to have_content 'Please fill in all required fields'
    end

    it 'displays an error if confirm password is empty and JS is on', js: true do
      fill_in 'Current password', with: @user.password
      fill_in 'New password', with: 'Val!dPassw0rd'
      fill_in 'Confirm your new password', with: ''
      click_button 'Change my password'

      expect(page).to have_content 'Please fill in all required fields'
    end

    it 'displays an error if only current password is provided and JS is on', js: true do
      fill_in 'Current password', with: @user.password
      click_button 'Change my password'

      expect(page).to have_content 'Please fill in all required fields'
    end
  end
end
