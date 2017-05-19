require 'rails_helper'

feature 'User profile' do
  include IdvHelper

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

      it 'allows the user reactivate their profile by reverifying' do
        profile = create(:profile, :active, pii: { ssn: '1234', dob: '1920-01-01' })
        user = profile.user

        sign_in_live_with_2fa(user)

        profile.deactivate(:password_reset)
        profile.reload
        visit account_path

        click_on t('account.index.reactivation.reverify')
        click_idv_begin

        # not using the helper method as the generic password doesn't seem to work
        fill_out_idv_form_ok
        click_idv_continue
        fill_out_financial_form_ok
        click_idv_continue
        click_idv_address_choose_phone
        fill_out_phone_form_ok(user.phone)
        click_idv_continue
        fill_in 'Password', with: user.password
        click_submit_default
        click_acknowledge_personal_key

        expect(current_path).to eq(account_path)
        visit account_path
        expect(page).not_to have_content(t('account.index.reactivation.instructions'))
      end
    end
  end
end
