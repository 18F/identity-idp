shared_examples 'gpo otp verification' do |options|
  include IdvStepHelper

  let(:expected_redirect_after_gpo_otp_verification) do
    if options && options[:redirect_after_verification]
      options[:redirect_after_verification].is_a?(Symbol) ?
        send(options[:redirect_after_verification]) :
        options[:redirect_after_verification]
    end
  end

  let(:account_should_be_verified) do
    !options || options[:account_should_be_verified] || options[:account_should_be_verified].nil?
  end

  let(:profile_should_be_active) do
    !options || options[:profile_should_be_active] || options[:profile_should_be_active].nil?
  end

  let(:expected_deactivation_reason) do
    options && options[:expected_profile_deactivation_reason]
  end

  it 'prompts for one-time code at sign in' do
    sign_in_live_with_2fa(user)

    expect(current_path).to eq idv_gpo_verify_path
    expect(page).to have_content t('idv.messages.gpo.resend')

    gpo_confirmation_code
    fill_in t('forms.verify_profile.name'), with: otp
    click_button t('forms.verify_profile.submit')

    if expected_redirect_after_gpo_otp_verification
      expect(page).to have_current_path(expected_redirect_after_gpo_otp_verification)
    end

    profile.reload

    if profile_should_be_active
      expect(profile.active).to be(true)
    else
      expect(profile.active).to be(false)
      if expected_deactivation_reason
        expect(profile.deactivation_reason).to eq(expected_deactivation_reason)
      end
    end

    if account_should_be_verified
      expect(user.events.account_verified.size).to eq 1
      expect(page).to_not have_content(t('account.index.verification.reactivate_button'))
    else
      expect(user.events.account_verified.size).to eq 0
    end
  end

  it 'renders an error for an expired GPO OTP' do
    sign_in_live_with_2fa(user)

    gpo_confirmation_code.update(code_sent_at: 11.days.ago)
    fill_in t('forms.verify_profile.name'), with: otp
    click_button t('forms.verify_profile.submit')

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
    expect(current_path).to eq idv_come_back_later_path

    confirmation_code = GpoConfirmationCode.first
    otp_fingerprint = Pii::Fingerprinter.fingerprint(otp)

    expect(confirmation_code.otp_fingerprint).to eq(otp_fingerprint)
    expect(confirmation_code.profile).to eq(profile)
  end
end
