require 'rails_helper'

RSpec.feature 'verify profile with OTP' do
  include IdvStepHelper

  let(:user) { create(:user, :fully_registered) }
  let(:otp) { 'ABC123' }

  before do
    profile = create(
      :profile,
      gpo_verification_pending_at: 1.day.ago,
      pii: { ssn: '666-66-1234', dob: '1920-01-01', phone: '+1 703-555-9999' },
      user: user,
    )
    otp_fingerprint = Pii::Fingerprinter.fingerprint(otp)
    create(:gpo_confirmation_code, profile: profile, otp_fingerprint: otp_fingerprint)
  end

  context 'GPO letter' do
    it 'shows step indicator progress with current step' do
      sign_in_live_with_2fa(user)

      expect_step_indicator_current_step(t('step_indicator.flows.idv.get_a_letter'))
    end

    scenario 'valid OTP' do
      sign_in_live_with_2fa(user)
      fill_in t('forms.verify_profile.name'), with: otp
      click_button t('forms.verify_profile.submit')
      acknowledge_and_confirm_personal_key

      expect(page).to have_current_path(account_path)
    end

    scenario 'OTP has expired' do
      GpoConfirmationCode.first.update(code_sent_at: 11.days.ago)

      sign_in_live_with_2fa(user)
      fill_in t('forms.verify_profile.name'), with: otp
      click_button t('forms.verify_profile.submit')

      expect(page).to have_content t('errors.messages.gpo_otp_expired')
      expect(current_path).to eq idv_gpo_verify_path
    end

    scenario 'wrong OTP used' do
      sign_in_live_with_2fa(user)
      fill_in t('forms.verify_profile.name'), with: 'the wrong code'
      click_button t('forms.verify_profile.submit')

      expect(current_path).to eq idv_gpo_verify_path
      expect(page).to have_content(t('errors.messages.confirmation_code_incorrect'))
      expect(page.body).to_not match('the wrong code')
    end
  end
end
