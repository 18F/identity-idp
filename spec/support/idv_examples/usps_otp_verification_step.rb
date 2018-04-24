shared_examples 'usps otp verfication step' do |sp|
  let(:otp) { 'ABC123' }
  let(:profile) do
    create(
      :profile,
      deactivation_reason: :verification_pending,
      phone_confirmed: false,
      pii: { ssn: '123-45-6789', dob: '1970-01-01' }
    )
  end
  let(:usps_confirmation_code) do
    create(
      :usps_confirmation_code,
      profile: profile,
      otp_fingerprint: Pii::Fingerprinter.fingerprint(otp)
    )
  end
  let(:user) { profile.user }

  it 'prompts for confirmation code at sign in' do
    sign_in_from_sp(sp)

    expect(current_path).to eq verify_account_path
    expect(page).to have_content t('idv.messages.usps.resend')

    usps_confirmation_code
    fill_in t('forms.verify_profile.name'), with: otp
    click_button t('forms.verify_profile.submit')

    expect(user.events.account_verified.size).to eq 1
    expect(page).to_not have_content(t('account.index.verification.reactivate_button'))

    if %i[saml oidc].include?(sp)
      expect(current_path).to eq(sign_up_completed_path)

      click_button t('forms.buttons.continue')

      if sp == :saml
        expect(current_url).to eq @saml_authn_request
      elsif sp == :oidc
        redirect_uri = URI(current_url)

        expect(redirect_uri.to_s).to start_with('http://localhost:7654/auth/result')
      end
    else
      expect(current_path).to eq account_path
    end
  end

  it 'renders an error for an expired USPS OTP' do
    sign_in_from_sp(sp)

    usps_confirmation_code.update(code_sent_at: 11.days.ago)
    fill_in t('forms.verify_profile.name'), with: otp
    click_button t('forms.verify_profile.submit')

    expect(current_path).to eq verify_account_path
    expect(page).to have_content t('errors.messages.usps_otp_expired')

    user.reload

    expect(user.events.account_verified.size).to eq 0
    expect(user.active_profile).to be_nil
  end

  it 'allows a user to resend a letter' do
    allow(Base32::Crockford).to receive(:encode).and_return(otp)

    sign_in_from_sp(sp)

    expect(UspsConfirmation.count).to eq(0)
    expect(UspsConfirmationCode.count).to eq(0)

    click_on t('idv.messages.usps.resend')
    click_on t('idv.buttons.mail.send')

    expect(UspsConfirmation.count).to eq(1)
    expect(UspsConfirmationCode.count).to eq(1)
    expect(current_path).to eq verify_come_back_later_path

    confirmation_code = UspsConfirmationCode.first
    otp_fingerprint = Pii::Fingerprinter.fingerprint(otp)

    expect(confirmation_code.otp_fingerprint).to eq(otp_fingerprint)
    expect(confirmation_code.profile).to eq(profile)
  end

  def sign_in_from_sp(sp)
    visit_idp_from_sp_with_loa3(sp)

    if %i[saml oidc].include?(sp)
      sign_in_via_branded_page(user)
    else
      sign_in_live_with_2fa(user)
    end
  end
end
