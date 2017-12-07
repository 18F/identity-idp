shared_examples 'selecting usps address verification method' do |sp|
  it 'allows the user to select verification via USPS letter', email: true do
    visit_idp_from_sp_with_loa3(sp)

    user = register_user

    click_idv_begin
    fill_out_idv_form_ok
    click_idv_continue

    click_idv_address_choose_usps
    click_on t('idv.buttons.mail.send')

    expect(current_path).to eq verify_review_path
    expect(page).to_not have_content t('idv.messages.phone.phone_of_record')

    fill_in :user_password, with: user_password

    expect { click_submit_default }.
      to change { UspsConfirmation.count }.from(0).to(1)

    expect(current_path).to eq verify_confirmations_path
    click_acknowledge_personal_key

    user.reload

    expect(user.events.account_verified.size).to be(0)
    expect(user.profiles.count).to eq 1

    profile = user.profiles.first

    expect(profile.active?).to eq false
    expect(profile.deactivation_reason).to eq 'verification_pending'
    expect(profile.phone_confirmed).to eq false

    usps_confirmation_entry = UspsConfirmation.last.decrypted_entry

    expect(current_path).to eq(verify_come_back_later_path)

    if sp == :saml
      expect(page).to have_link(t('idv.buttons.return_to_account'))
      expect(usps_confirmation_entry.issuer).
        to eq('https://rp1.serviceprovider.com/auth/saml/metadata')
    elsif sp == :oidc
      expect(page).to have_link(t('idv.buttons.continue_plain'))
      expect(usps_confirmation_entry.issuer).
        to eq('urn:gov:gsa:openidconnect:sp:server')
    end
  end

  describe 'USPS OTP prefilling' do
    it 'prefills USPS OTP if the reveal_usps_code feature flag is set', email: true do
      visit_idp_from_sp_with_loa3(sp)
      register_user

      usps_confirmation_maker = instance_double(UspsConfirmationMaker)
      allow(usps_confirmation_maker).to receive(:otp).and_return('123ABC')
      allow(usps_confirmation_maker).to receive(:perform)
      allow(UspsConfirmationMaker).to receive(:new).and_return(usps_confirmation_maker)
      allow(FeatureManagement).to receive(:reveal_usps_code?).and_return(true)

      complete_idv_profile_ok_with_usps

      visit verify_account_path

      expect(page.find('#verify_account_form_otp').value).to eq '123ABC'
    end

    it 'does not prefill USPS OTP if the reveal_usps_code feature flag is not set', email: true do
      visit_idp_from_sp_with_loa3(sp)
      register_user

      usps_confirmation_maker = instance_double(UspsConfirmationMaker)
      allow(usps_confirmation_maker).to receive(:otp).and_return('123ABC')
      allow(usps_confirmation_maker).to receive(:perform)
      allow(UspsConfirmationMaker).to receive(:new).and_return(usps_confirmation_maker)
      allow(FeatureManagement).to receive(:prefill_otp_codes?).and_return(false)

      complete_idv_profile_ok_with_usps

      visit verify_account_path

      expect(page.find('#verify_account_form_otp').value).to be_nil
    end
  end

  def complete_idv_profile_ok_with_usps
    click_idv_begin
    fill_out_idv_form_ok
    click_idv_continue
    click_idv_address_choose_usps
    click_on t('idv.buttons.mail.send')
    fill_in :user_password, with: user_password
    click_submit_default
  end
end
