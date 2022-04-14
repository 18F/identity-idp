require 'rails_helper'

feature 'User profile' do
  include IdvStepHelper
  include NavigationHelper
  include PersonalKeyHelper
  include PushNotificationsHelper

  context 'account status badges' do
    before do
      sign_in_live_with_2fa(profile.user)
    end

    context 'IAL2 account' do
      let(:profile) { create(:profile, :active, :verified, pii: { ssn: '111', dob: '1920-01-01' }) }

      it 'shows a "Verified Account" badge with no tooltip' do
        expect(page).to have_content(t('headings.account.verified_account'))
      end
    end
  end

  context 'ial1 user clicks the delete account button' do
    let(:push_notification_url) { 'http://localhost/push_notifications' }

    it 'deletes the account and signs the user out with a flash message' do
      user = sign_in_and_2fa_user
      user.agency_identities << AgencyIdentity.create(user_id: user.id, agency_id: 1, uuid: '1234')
      visit account_path

      find_sidenav_delete_account_link.click
      expect(User.count).to eq 1
      expect(AgencyIdentity.count).to eq 1

      fill_in(t('idv.form.password'), with: Features::SessionHelper::VALID_PASSWORD)
      click_button t('users.delete.actions.delete')
      expect(page).to have_content t('devise.registrations.destroyed')
      expect(current_path).to eq root_path
      expect(User.count).to eq 0
      expect(AgencyIdentity.count).to eq 0
    end

    it 'deletes the account and pushes notifications if push_notifications_enabled is true' do
      allow(IdentityConfig.store).to receive(:push_notifications_enabled).and_return(true)

      service_provider = build(:service_provider, issuer: 'urn:gov:gsa:openidconnect:test')
      user = sign_in_and_2fa_user
      identity = IdentityLinker.new(user, service_provider).link_identity
      agency_identity = AgencyIdentityLinker.new(identity).link_identity

      visit account_path

      find_sidenav_delete_account_link.click

      request = stub_push_notification_request(
        sp_push_notification_endpoint: push_notification_url,
        event_type: PushNotification::AccountPurgedEvent::EVENT_TYPE,
        payload: {
          'subject' => {
            'subject_type' => 'iss-sub',
            'iss' => Rails.application.routes.url_helpers.root_url,
            'sub' => agency_identity.uuid,
          },
        },
      )

      fill_in(t('idv.form.password'), with: Features::SessionHelper::VALID_PASSWORD)
      click_button t('users.delete.actions.delete')
      expect(request).to have_been_requested
    end
  end

  context 'ial2 user clicks the delete account button' do
    it 'deletes the account and signs the user out with a flash message' do
      profile = create(:profile, :active, :verified, pii: { ssn: '1234', dob: '1920-01-01' })
      sign_in_live_with_2fa(profile.user)
      visit account_path

      find_sidenav_delete_account_link.click
      expect(User.count).to eq 1
      expect(Profile.count).to eq 1

      fill_in(t('idv.form.password'), with: profile.user.password)
      click_button t('users.delete.actions.delete')
      expect(page).to have_content t('devise.registrations.destroyed')
      expect(current_path).to eq root_path
      expect(User.count).to eq 0
      expect(Profile.count).to eq 0
    end

    it 'allows credentials to be reused for sign up' do
      expect(User.count).to eq 0
      pii = { ssn: '1234', dob: '1920-01-01' }
      profile = create(:profile, :active, :verified, pii: pii)
      expect(User.count).to eq 1
      sign_in_live_with_2fa(profile.user)
      visit account_path
      find_sidenav_delete_account_link.click
      fill_in(t('idv.form.password'), with: profile.user.password)
      click_button t('users.delete.actions.delete')

      expect(User.count).to eq 0

      profile = create(:profile, :active, :verified, pii: pii)
      sign_in_live_with_2fa(profile.user)
      expect(User.count).to eq 1
      expect(Profile.count).to eq 1
    end
  end

  describe 'Editing the password' do
    it 'includes the password strength indicator when JS is on', js: true do
      sign_in_and_2fa_user
      within('.sidenav') do
        click_link 'Edit', href: manage_password_path
      end

      expect(page).to_not have_css('#pw-strength-cntnr.display-none')
      expect(page).to have_content '...'

      fill_in t('forms.passwords.edit.labels.password'), with: 'this is a great sentence'
      expect(page).to have_content 'Great'

      check t('components.password_toggle.toggle_label')

      expect(page).to_not have_css('input.password[type="password"]')
      expect(page).to have_css('input.password[type="text"]')

      click_button 'Update'

      expect(current_path).to eq account_path
    end

    context 'IAL2 user' do
      it 'generates a new personal key' do
        profile = create(:profile, :active, :verified, pii: { ssn: '1234', dob: '1920-01-01' })
        sign_in_live_with_2fa(profile.user)

        visit manage_password_path
        fill_in t('forms.passwords.edit.labels.password'), with: 'this is a great sentence'
        click_button 'Update'

        expect(current_path).to eq account_path
        expect(page).to have_content(t('idv.messages.personal_key'))
      end

      it 'allows the user reactivate their profile by reverifying' do
        profile = create(:profile, :active, :verified, pii: { ssn: '1234', dob: '1920-01-01' })
        user = profile.user

        trigger_reset_password_and_click_email_link(user.email)
        reset_password_and_sign_back_in(user, user_password)
        click_submit_default
        fill_in_code_with_last_phone_otp
        click_submit_default
        click_on t('links.account.reactivate.without_key')
        complete_all_doc_auth_steps
        click_idv_continue
        fill_in 'Password', with: user_password
        click_idv_continue
        click_acknowledge_personal_key

        expect(current_path).to eq(sign_up_completed_path)

        click_agree_and_continue

        expect(current_url).to start_with('http://localhost:7654/auth/result')
      end
    end
  end
end
