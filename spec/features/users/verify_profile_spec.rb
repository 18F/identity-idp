require 'rails_helper'

feature 'verify profile with OTP' do
  let(:user) { create(:user, :signed_up) }
  let(:otp) { 'ABC123' }

  before do
    profile = create(
      :profile,
      deactivation_reason: :verification_pending,
      pii: { ssn: '666-66-1234', dob: '1920-01-01', phone: '555-555-9999' },
      phone_confirmed: phone_confirmed,
      user: user
    )
    otp_fingerprint = Pii::Fingerprinter.fingerprint(otp)
    create(:usps_confirmation_code, profile: profile, otp_fingerprint: otp_fingerprint)
  end

  context 'USPS letter' do
    let(:phone_confirmed) { false }

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

  context 'profile phone confirmed' do
    let(:phone_confirmed) { true }

    before do
      allow(FeatureManagement).to receive(:prefill_otp_codes?).and_return(true)
    end

    scenario 'not yet verified with user' do
      sign_in_live_with_2fa(user)
      click_submit_default

      expect(current_path).to eq account_path
      expect(page).to_not have_content(t('account.index.verification.with_phone_button'))
    end
  end
end
