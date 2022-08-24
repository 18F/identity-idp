require 'rails_helper'

feature 'verify profile with OTP' do
  let(:user) { create(:user, :signed_up) }
  let(:otp) { 'ABC123' }

  before do
    profile = create(
      :profile,
      deactivation_reason: :gpo_verification_pending,
      pii: { ssn: '666-66-1234', dob: '1920-01-01', phone: '+1 703-555-9999' },
      user: user,
    )
    otp_fingerprint = Pii::Fingerprinter.fingerprint(otp)
    create(:gpo_confirmation_code, profile: profile, otp_fingerprint: otp_fingerprint)
  end

  context 'GPO letter' do
    it 'shows step indicator progress with current verify step, completed secure account' do
      sign_in_live_with_2fa(user)

      expect_step_indicator_current_step(t('step_indicator.flows.idv.verify_phone_or_address'))
      expect(page).to have_css(
        '.step-indicator__step--complete',
        text: t('step_indicator.flows.idv.secure_account'),
      )
    end

    scenario 'valid OTP' do
      sign_in_live_with_2fa(user)
      fill_in t('forms.verify_profile.name'), with: otp
      click_button t('forms.verify_profile.submit')

      expect(page).to have_content(t('account.index.verification.success'))
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
