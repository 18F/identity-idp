require 'rails_helper'

feature 'A user with a UAK passwords attempts IdV' do
  include IdvStepHelper

  context 'before we start writing 2L-KMS passwords' do
    before do
      allow(FeatureManagement).to receive(:write_2lkms_passwords?).and_return(true)
    end

    it 'allows the user to continue to the SP' do
      user = user_with_2fa
      user.update!(
        encrypted_password_digest: Encryption::UakPasswordVerifier.digest(user.password),
      )

      start_idv_from_sp(:oidc)
      complete_idv_steps_with_phone_before_confirmation_step(user)

      click_acknowledge_personal_key

      expect(page).to have_current_path(sign_up_completed_path)

      click_on t('forms.buttons.continue')

      expect(current_url).to start_with('http://localhost:7654/auth/result')
    end
  end

  context 'after we start writing 2L-KMS passwords' do
    it 'allows the user to continue to the SP' do
      user = user_with_2fa
      user.update!(
        encrypted_password_digest: Encryption::UakPasswordVerifier.digest(user.password),
      )

      start_idv_from_sp(:oidc)
      complete_idv_steps_with_phone_before_confirmation_step(user)

      click_acknowledge_personal_key

      expect(page).to have_current_path(sign_up_completed_path)

      click_on t('forms.buttons.continue')

      expect(current_url).to start_with('http://localhost:7654/auth/result')
    end
  end
end
