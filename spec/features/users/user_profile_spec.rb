require 'rails_helper'

RSpec.feature 'User profile' do
  include IdvStepHelper
  include NavigationHelper
  include PersonalKeyHelper
  include PushNotificationsHelper
  include BrowserEmulationHelper

  context 'account status badges' do
    before do
      sign_in_live_with_2fa(profile.user)
    end

    context 'IAL2 account' do
      let(:profile) { create(:profile, :active, :verified, pii: { ssn: '111', dob: '1920-01-01' }) }

      it 'shows a "Verified Account" badge with no tooltip' do
        expect(page).to have_content(t('account.index.verification.verified_badge'))
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
      expect(page).to have_current_path root_path
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
      expect(page).to have_current_path root_path
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

      expect(page).not_to have_content(t('instructions.password.strength.intro'))

      fill_in t('forms.passwords.edit.labels.password'), with: 'this is a great sentence'
      fill_in t('components.password_confirmation.confirm_label'),
              with: 'this is a great sentence'

      expect(page).to have_content(t('instructions.password.strength.intro'))
      expect(page).to have_content t('instructions.password.strength.4')

      check t('components.password_toggle.toggle_label')

      expect(page).to_not have_css('input.password[type="password"]')
      expect(page).to have_css('input.password[type="text"]')

      click_button 'Update'

      expect(page).to have_current_path account_path
    end

    context 'IAL2 user' do
      it 'generates a new personal key' do
        profile = create(:profile, :active, :verified, pii: { ssn: '1234', dob: '1920-01-01' })
        sign_in_live_with_2fa(profile.user)

        visit manage_password_path
        fill_in t('forms.passwords.edit.labels.password'), with: 'this is a great sentence'
        fill_in t('components.password_confirmation.confirm_label'),
                with: 'this is a great sentence'
        click_button 'Update'

        expect(page).to have_content(t('forms.personal_key_partial.header'))
        expect(page).to have_current_path(manage_personal_key_path)

        personal_key = PersonalKeyGenerator.new(profile.user).normalize(scrape_personal_key)

        expect(profile.user.reload.valid_personal_key?(personal_key)).to eq(true)

        click_continue

        expect(page).to have_current_path(account_path)
      end

      it 'allows the user reactivate their profile by reverifying', :js do
        profile = create(:profile, :active, :verified, pii: { ssn: '1234', dob: '1920-01-01' })
        user = profile.user

        trigger_reset_password_and_click_email_link(user.email)
        reset_password_and_sign_back_in(user, user_password)
        click_submit_default
        fill_in_code_with_last_phone_otp
        click_submit_default
        click_on t('links.account.reactivate.without_key')
        complete_all_doc_auth_steps_before_password_step
        fill_in 'Password', with: user_password
        click_idv_continue
        acknowledge_and_confirm_personal_key

        # page.driver.debug(binding)
        binding.pry
        expect(page).to have_current_path(sign_up_completed_path)

        click_agree_and_continue

        # This currently fails to connect, which is fine for selenium, but not for cuprite?
        expect(page).to have_current_path(
          'http://localhost:7654/auth/result',
          url: true,
          ignore_query: true,
        )
      end
    end
  end

  context 'with a mobile device', js: true, driver: :headless_chrome_mobile do
    before { sign_in_and_2fa_user }

    it 'allows a user to navigate between pages' do
      # Emulate reduced motion to avoid timing issues with mobile menu flyout animation
      emulate_reduced_motion
      click_on t('account.navigation.menu')
      click_link t('account.navigation.history')

      expect(page).to have_current_path(account_history_path)
    end
  end

  context 'allows verified user to see their information' do
    context 'time between sign in and remember device' do
      it 'shows PII when timeout hasnt expired' do
        profile = create(
          :profile, :active, :verified,
          pii: Idp::Constants::MOCK_IDV_APPLICANT_WITH_PHONE
        )
        sign_in_user(profile.user)
        check t('forms.messages.remember_device')
        fill_in_code_with_last_phone_otp
        click_submit_default
        visit account_path
        expect(page).to_not have_button(t('account.re_verify.footer'))

        dob = Idp::Constants::MOCK_IDV_APPLICANT[:dob]
        parsed_date = DateParser.parse_legacy(dob).to_formatted_s(:long)
        expect(page).to have_content(parsed_date)
      end
    end

    context 'when time expired' do
      it 'has a prompt to authenticate device and pii isnt visible until reauthenticate' do
        profile = create(
          :profile, :active, :verified,
          pii: Idp::Constants::MOCK_IDV_APPLICANT_WITH_PHONE
        )
        user = profile.user
        sign_in_user(user)
        dob = Idp::Constants::MOCK_IDV_APPLICANT[:dob]
        parsed_date = DateParser.parse_legacy(dob).to_formatted_s(:long)

        check t('forms.messages.remember_device')
        fill_in_code_with_last_phone_otp
        click_submit_default

        timeout_in_minutes = IdentityConfig.store.pii_lock_timeout_in_minutes.to_i
        travel_to((timeout_in_minutes + 1).minutes.from_now) do
          sign_in_user(user)
          visit account_path
          expect(page).to have_button(t('account.re_verify.footer'))
          expect(page).to_not have_content(parsed_date)
          click_button t('account.re_verify.footer')
          expect(page)
            .to have_content t('two_factor_authentication.login_options.sms')
          click_button t('forms.buttons.continue')
          fill_in_code_with_last_phone_otp
          click_submit_default
          expect(page).to have_content(parsed_date)
        end
      end
    end
  end
end
