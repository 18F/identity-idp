RSpec.shared_examples 'gpo otp verification' do
  include IdvStepHelper

  it 'prompts for one-time code at sign in' do
    sign_in_live_with_2fa(user)

    expect(current_path).to eq idv_gpo_verify_path
    expect(page).to have_content t('idv.messages.gpo.resend')

    gpo_confirmation_code
    fill_in t('idv.gpo.form.otp_label'), with: otp
    click_button t('idv.gpo.form.submit')

    profile.reload

    if profile_should_be_active
      expect(profile.active).to be(true)
      expect(profile.deactivation_reason).to be(nil)
      expect(user.events.account_verified.size).to eq 1
    else
      expect(profile.active).to be(false)
      expect(profile.fraud_review_pending?).to eq(fraud_review_pending) if fraud_review_pending
      expect(profile.deactivation_reason).to eq(nil) if fraud_review_pending
    end

    expect(page).to_not have_content(t('account.index.verification.reactivate_button'))
  end

  it 'renders an error for an expired GPO OTP' do
    sign_in_live_with_2fa(user)

    gpo_confirmation_code.update(
      code_sent_at: (IdentityConfig.store.usps_confirmation_max_days + 1).days.ago,
    )
    fill_in t('idv.gpo.form.otp_label'), with: otp
    click_button t('idv.gpo.form.submit')

    expect(current_path).to eq idv_gpo_verify_path
    expect(page).to have_content t('errors.messages.gpo_otp_expired')

    user.reload

    expect(user.events.account_verified.size).to eq 0
    expect(user.active_profile).to be_nil
  end

  it 'allows a user to resend a letter' do
    allow(Base32::Crockford).to receive(:encode).and_return(otp)

    sign_in_live_with_2fa(user)

    expect(GpoConfirmation.count).to eq(0)
    expect(GpoConfirmationCode.count).to eq(0)
    click_on t('idv.messages.gpo.resend')

    expect_step_indicator_current_step(t('step_indicator.flows.idv.get_a_letter'))

    click_on t('idv.buttons.mail.resend')

    expect(GpoConfirmation.count).to eq(1)
    expect(GpoConfirmationCode.count).to eq(1)
    expect(current_path).to eq idv_letter_enqueued_path

    confirmation_code = GpoConfirmationCode.first
    otp_fingerprint = Pii::Fingerprinter.fingerprint(otp)

    expect(confirmation_code.otp_fingerprint).to eq(otp_fingerprint)
    expect(confirmation_code.profile).to eq(profile)
  end
end
