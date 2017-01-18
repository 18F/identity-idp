require 'rails_helper'

feature 'View recovery code' do
  context 'during sign up' do
    scenario 'user sees progress bar on recovery code page' do
      sign_up_and_view_recovery_code

      expect(page).to have_css('.step-3.active')
    end

    scenario 'user refreshes recovery code page' do
      sign_up_and_view_recovery_code

      visit sign_up_recovery_code_path

      expect(current_path).to eq(profile_path)
    end
  end

  context 'after sign up' do
    scenario 'does not display progress bar' do
      sign_in_and_2fa_user

      click_link t('profile.links.regenerate_recovery_code')

      expect(page).to_not have_css('.step-3.active')
    end

    context 'regenerating recovery code' do
      scenario 'displays new code and returns user to profile page' do
        user = sign_in_and_2fa_user
        old_code = user.recovery_code

        click_link t('profile.links.regenerate_recovery_code')

        expect(user.reload.recovery_code).to_not eq old_code

        click_button t('forms.buttons.continue')

        expect(current_path).to eq profile_path
      end
    end

    context 'regenerating recovery code with `Get another code` button' do
      scenario 'displays a flash message and a new code' do
        user = sign_in_and_2fa_user

        click_link t('profile.links.regenerate_recovery_code')
        old_code = user.reload.recovery_code

        click_link t('users.recovery_code.get_another')

        expect(user.reload.recovery_code).to_not eq old_code
        expect(page).to have_content t('notices.send_code.recovery_code')
      end
    end

    context 'regenerating new code after canceling edit password action' do
      scenario 'displays new code and returns user to profile page' do
        allow(Figaro.env).to receive(:reauthn_window).and_return('0')

        sign_in_and_2fa_user
        first(:link, t('forms.buttons.edit')).click
        click_on(t('links.cancel'))
        click_on(t('profile.links.regenerate_recovery_code'))
        click_on(t('forms.buttons.continue'))

        expect(current_path).to eq(profile_path)
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
end
