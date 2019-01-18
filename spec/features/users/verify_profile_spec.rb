require 'rails_helper'

feature 'verify profile with OTP' do
  let(:user) { create(:user, :signed_up) }
  let(:otp) { 'ABC123' }

  before do
    profile = create(
      :profile,
      deactivation_reason: :verification_pending,
      pii: { ssn: '666-66-1234', dob: '1920-01-01', phone: '+1 703-555-9999' },
      user: user,
    )
    otp_fingerprint = Pii::Fingerprinter.fingerprint(otp)
    create(:usps_confirmation_code, profile: profile, otp_fingerprint: otp_fingerprint)
  end

  context 'USPS letter' do
    scenario 'valid OTP' do
      sign_in_live_with_2fa(user)
      fill_in t('forms.verify_profile.name'), with: otp
      click_button t('forms.verify_profile.submit')

      expect(page).to have_content(t('account.index.verification.success'))
      expect(page).to have_current_path(account_path)
    end

    scenario 'OTP has expired' do
      UspsConfirmationCode.first.update(code_sent_at: 11.days.ago)

      sign_in_live_with_2fa(user)
      fill_in t('forms.verify_profile.name'), with: otp
      click_button t('forms.verify_profile.submit')

      expect(page).to have_content t('errors.messages.usps_otp_expired')
      expect(current_path).to eq verify_account_path
    end

    scenario 'wrong OTP used' do
      sign_in_live_with_2fa(user)
      fill_in t('forms.verify_profile.name'), with: 'the wrong code'
      click_button t('forms.verify_profile.submit')

      expect(current_path).to eq verify_account_path
      expect(page).to have_content(t('errors.messages.confirmation_code_incorrect'))
      expect(page.body).to_not match('the wrong code')
    end
  end
end
