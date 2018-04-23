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

    expect { click_continue }.
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
      expect(page).to have_link(t('idv.buttons.continue_plain'))
      expect(usps_confirmation_entry.issuer).
        to eq('https://rp1.serviceprovider.com/auth/saml/metadata')
    elsif sp == :oidc
      expect(page).to have_link(t('idv.buttons.continue_plain'))
      expect(usps_confirmation_entry.issuer).
        to eq('urn:gov:gsa:openidconnect:sp:server')
    end
  end
end
