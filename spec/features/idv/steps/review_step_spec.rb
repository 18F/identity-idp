require 'rails_helper'

feature 'idv review step', :idv_job do
  include IdvStepHelper

  it 'requires the user to enter the correct password to redirect to confirmation step' do
    start_idv_from_sp
    complete_idv_steps_before_review_step

    expect(page).to have_content('José')
    expect(page).to have_content('One')
    expect(page).to have_content('123 Main St')
    expect(page).to have_content('Nowhere, VA 6604')
    expect(page).to have_content('January 02, 1980')
    expect(page).to have_content('666-66-1234')
    expect(page).to have_content('+1 (555) 555-0000')

    fill_in 'Password', with: 'this is not the right password'
    click_idv_continue

    expect(page).to have_content(t('idv.errors.incorrect_password'))
    expect(page).to have_current_path(verify_review_path)

    fill_in 'Password', with: user_password
    click_idv_continue

    expect(page).to have_content(t('headings.personal_key'))
    expect(page).to have_current_path(verify_confirmations_path)
  end

  context 'choosing to confirm address with phone' do
    let(:user) { user_with_2fa }

    before do
      start_idv_from_sp
      complete_idv_steps_with_phone_before_review_step(user)
    end

    it 'does not send a letter and creates a verified profile' do
      fill_in 'Password', with: user_password
      click_idv_continue

      expect(user.events.account_verified.size).to be(1)
      expect(user.profiles.count).to eq 1

      profile = user.profiles.first

      expect(profile.active?).to eq true
      expect(profile.phone_confirmed).to eq true
      expect(UspsConfirmation.count).to eq(0)
    end
  end

  context 'choosing to confirm address with usps' do
    let(:user) { user_with_2fa }
    let(:sp) { :oidc }

    before do
      start_idv_from_sp(sp)
      complete_idv_steps_with_usps_before_review_step(user)
    end

    it 'sends a letter and creates an unverified profile' do
      fill_in 'Password', with: user_password

      expect { click_continue }.
        to change { UspsConfirmation.count }.from(0).to(1)

      expect(user.events.account_verified.size).to be(0)
      expect(user.profiles.count).to eq 1

      profile = user.profiles.first

      expect(profile.active?).to eq false
      expect(profile.phone_confirmed).to eq false
    end

    context 'with an sp' do
      it 'sends a letter with a reference the sp' do
        fill_in 'Password', with: user_password
        click_continue

        usps_confirmation_entry = UspsConfirmation.last.decrypted_entry

        if sp == :saml
          expect(usps_confirmation_entry.issuer).
            to eq('https://rp1.serviceprovider.com/auth/saml/metadata')
        else
          expect(usps_confirmation_entry.issuer).
            to eq('urn:gov:gsa:openidconnect:sp:server')
        end
      end
    end

    context 'without an sp' do
      let(:sp) { nil }

      it 'sends a letter without a reference to the sp' do
        fill_in 'Password', with: user_password
        click_continue

        usps_confirmation_entry = UspsConfirmation.last.decrypted_entry

        expect(usps_confirmation_entry.issuer).to eq(nil)
      end
    end
  end
end
