require 'rails_helper'

feature 'User edit' do
  let(:user) { create(:user, :signed_up) }

  context 'deleting 2FA phone number' do
    before do
      sign_in_and_2fa_user(user)
      visit manage_phone_path
    end

    scenario 'delete not an option if no other mfa configured' do
      expect(MfaPolicy.new(user).multiple_factors_enabled?).to eq true

      expect(page).to_not have_button(t('forms.buttons.delete'))
    end

    context 'with multiple mfa configured' do
      let(:user) { create(:user, :signed_up, :with_piv_or_cac) }

      scenario 'delete is an option that works' do
        expect(MfaPolicy.new(user).multiple_factors_enabled?).to eq true

        expect(page).to have_button(t('forms.phone.buttons.delete'))
        click_button t('forms.phone.buttons.delete')
        expect(page).to have_current_path(account_path)
        expect(MfaPolicy.new(user.reload).multiple_factors_enabled?).to eq true
        expect(page).to have_content t('event_types.phone_removed')
      end
    end
  end

  context 'editing password' do
    before do
      sign_in_and_2fa_user(user)
      visit manage_password_path
    end

    scenario 'user sees error message if form is submitted with invalid password' do
      fill_in 'New password', with: 'foo'
      click_button 'Update'

      expect(page).
        to have_content t('errors.messages.too_short.other', count: Devise.password_length.first)
    end
  end
end
