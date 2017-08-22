require 'rails_helper'

feature 'verify profile with OTP' do
  let(:user) { create(:user, :signed_up) }
  let(:otp) { 'abc123' }

  before do
    create(
      :profile,
      deactivation_reason: :verification_pending,
      pii: { otp: otp, ssn: '666-66-1234', dob: '1920-01-01', phone: '555-555-9999' },
      phone_confirmed: phone_confirmed,
      user: user
    )
  end

  context 'USPS letter' do
    let(:phone_confirmed) { false }

    xscenario 'OTP has expired' do
      # see https://github.com/18F/identity-private/issues/1108#issuecomment-293328267
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
