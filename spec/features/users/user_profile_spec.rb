require 'rails_helper'

feature 'User profile' do
  include IdvHelper
  include PersonalKeyHelper

  context 'account status badges' do
    before do
      sign_in_live_with_2fa(profile.user)
    end

    context 'LOA3 account' do
      let(:profile) { create(:profile, :active, :verified, pii: { ssn: '111', dob: '1920-01-01' }) }

      it 'shows a "Verified Account" badge with no tooltip' do
        expect(page).to have_content(t('headings.account.verified_account'))
      end
    end
  end

  context 'user clicks the delete account button' do
    xit 'deletes the account and signs the user out with a flash message' do
      pending 'temporarily disabled until we figure out the MBUN to SSN mapping'
      sign_in_and_2fa_user
      visit account_path
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

      expect(current_path).to eq account_path
    end

    context 'LOA3 user' do
      it 'generates a new personal key' do
        profile = create(:profile, :active, :verified, pii: { ssn: '1234', dob: '1920-01-01' })
        sign_in_live_with_2fa(profile.user)

        visit manage_password_path
        fill_in 'update_user_password_form_password', with: 'this is a great sentence'
        click_button 'Update'

        expect(current_path).to eq account_path
        expect(page).to have_content(t('idv.messages.personal_key'))
      end

      it 'allows the user reactivate their profile by reverifying', idv_job: true do
        profile = create(:profile, :active, :verified, pii: { ssn: '1234', dob: '1920-01-01' })
        user = profile.user

        trigger_reset_password_and_click_email_link(user.email)
        reset_password_and_sign_back_in(user, user_password)
        click_submit_default
        enter_correct_otp_code_for_user(user)
        click_on t('links.account.reactivate.without_key')
        click_idv_begin
        complete_idv_profile_ok(user)
        click_acknowledge_personal_key

        expect(current_path).to eq(account_path)

        visit account_path

        expect(page).not_to have_content(t('account.index.reactivation.instructions'))
      end
    end
  end
end
