require 'rails_helper'

feature 'OTP delivery selection' do
  context 'set up a number as 2FA for voice' do
    let(:user) { create(:user) }

    before do
      sign_in_user(user)
      select_2fa_option('voice')
      fill_in 'user_phone_form[phone]', with: '202-555-1212'
      click_send_security_code
      fill_in_code_with_last_phone_otp
      click_submit_default
    end

    it 'should fail if using the same number as backup MFA voice' do
      expect(page).to have_current_path(two_factor_options_path)
      select_2fa_option('voice')
      expect(page).to have_content t('titles.phone_setup.voice')
      fill_in 'user_phone_form[phone]', with: '202-555-1212'
      click_send_security_code
      expect(page).to have_content(t('errors.messages.phone_duplicate'))
    end

    it 'should success if using a new number as backup MFA voice' do
      choose_phone_as_backup_mfa
    end

    it 'should prevent changing one phone to the other number' do
      choose_phone_as_backup_mfa
      fill_in_code_with_last_phone_otp
      click_submit_default

      expect(current_path).to eq(account_path)

      first_phone = user.phone_configurations.first
      second_phone = user.phone_configurations.last
      visit manage_phone_path(id: first_phone.id)
      fill_in 'user_phone_form[phone]', with: second_phone.phone
      click_button t('forms.buttons.submit.confirm_change')

      expect(page).to have_content(t('errors.messages.phone_duplicate'))
    end

    def choose_phone_as_backup_mfa
      expect(page).to have_current_path(two_factor_options_path)
      select_2fa_option('voice')
      expect(page).to have_content t('titles.phone_setup.voice')
      fill_in 'user_phone_form[phone]', with: '202-555-1213'
      click_send_security_code
      expect(page).to have_content(t('two_factor_authentication.header_text'))
    end
  end
end
