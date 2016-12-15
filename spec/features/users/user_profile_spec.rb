require 'rails_helper'

feature 'User profile' do
  context 'user clicks the delete account button' do
    xit 'deletes the account and signs the user out with a flash message' do
      pending 'temporarily disabled until we figure out the MBUN to SSN mapping'
      sign_in_and_2fa_user
      visit profile_path
      click_button t('forms.buttons.delete_account')

      click_button t('forms.buttons.delete_account_confirm')
      expect(page).to have_content t('devise.registrations.destroyed')
      expect(current_path).to eq root_path
      expect(User.count).to eq 0
    end
  end

  describe 'Editing the password' do
    it 'includes the password strength indicator when JS is on', js: true do
      sign_in_and_2fa_user
      click_link 'Edit', href: manage_password_path

      expect(page).to_not have_css('#pw-strength-cntnr.hide')
      expect(page).to have_content '...'

      fill_in 'update_user_password_form_password', with: 'this is a great sentence'
      expect(page).to have_content 'Great'

      find('#pw-toggle-0', visible: false).trigger('click')

      expect(page).to_not have_css('input.password[type="password"]')
      expect(page).to have_css('input.password[type="text"]')

      click_button 'Update'

      expect(current_path).to eq profile_path
    end

    context 'LOA3 user' do
      it 'generates a new recovery code' do
        profile = create(:profile, :active, :verified, pii: { ssn: '1234', dob: '1920-01-01' })
        sign_in_live_with_2fa(profile.user)

        visit manage_password_path
        fill_in 'update_user_password_form_password', with: 'this is a great sentence'
        click_button 'Update'

        expect(current_path).to eq profile_path
        expect(page).to have_content(t('idv.messages.recovery_code'))
      end
    end
  end

  describe 'Regenerating recovery code' do
    it 'displays new code and takes user back to profile page after continuing' do
      user = sign_in_and_2fa_user
      old_code = user.recovery_code

      click_link t('profile.links.regenerate_recovery_code')

      expect(user.reload.recovery_code).to_not eq old_code

      click_button t('forms.buttons.continue')

      expect(current_path).to eq profile_path
    end

    it 'does not display progress bar' do
      sign_in_and_2fa_user

      click_link t('profile.links.regenerate_recovery_code')

      expect(page).to_not have_css('.step-3.active')
    end
  end
end
