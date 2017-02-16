require 'rails_helper'

feature 'View recovery code' do
  context 'during sign up' do
    scenario 'user refreshes recovery code page' do
      sign_up_and_view_recovery_code

      visit sign_up_recovery_code_path

      expect(current_path).to eq(profile_path)
    end
  end

  context 'after sign up' do
    context 'regenerating recovery code' do
      scenario 'displays new code' do
        user = sign_in_and_2fa_user
        old_code = user.recovery_code

        click_link t('profile.links.regenerate_recovery_code')

        expect(user.reload.recovery_code).to_not eq old_code
      end
    end

    context 'regenerating new code after canceling edit password action' do
      scenario 'displays new code' do
        allow(Figaro.env).to receive(:reauthn_window).and_return('0')

        user = sign_in_and_2fa_user

        old_code = user.recovery_code

        first(:link, t('forms.buttons.edit')).click
        click_on(t('links.cancel'))
        click_on(t('profile.links.regenerate_recovery_code'))

        expect(user.reload.recovery_code).to_not eq old_code
      end
    end

    context 'recovery code actions and information' do
      before do
        @user = sign_in_and_2fa_user
        click_link t('profile.links.regenerate_recovery_code')
      end

      it_behaves_like 'recovery code page'
    end
  end
end

def sign_up_and_view_recovery_code
  allow(FeatureManagement).to receive(:prefill_otp_codes?).and_return(true)
  sign_up_and_set_password
  fill_in 'Phone', with: '202-555-1212'
  click_button t('forms.buttons.send_passcode')
  click_button t('forms.buttons.submit.default')
end
