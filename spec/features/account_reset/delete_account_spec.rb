require 'rails_helper'

describe 'Account Reset Request: Delete Account', email: true do
  include PushNotificationsHelper

  let(:user) { create(:user, :signed_up) }
  let(:user_email) { user.email_addresses.first.email }
  let(:push_notification_url) { 'http://localhost/push_notifications' }

  context 'as an IAL1 user' do
    it 'allows the user to delete their account after 24 hours' do
      signin(user_email, user.password)
      click_link t('two_factor_authentication.login_options_link_text')
      click_link t('two_factor_authentication.account_reset.link')
      click_button t('account_reset.request.yes_continue')

      expect(page).
        to have_content strip_tags(
          t('account_reset.confirm_request.instructions_start'),
        )
      expect(page).
        to have_content user_email
      expect(page).
        to have_content strip_tags(
          t('account_reset.confirm_request.instructions_end'),
        )
      expect(page).to have_content t('account_reset.confirm_request.security_note')
      expect(page).to have_content t('account_reset.confirm_request.close_window')

      reset_email

      travel_to(Time.zone.now + 2.days + 1) do
        AccountReset::GrantRequestsAndSendEmails.new.perform(Time.zone.today)
        open_last_email
        click_email_link_matching(/delete_account\?token/)

        expect(page).to have_content(t('account_reset.delete_account.title'))
        expect(page).to have_current_path(account_reset_delete_account_path)

        click_button t('account_reset.request.yes_continue')

        expect(page).to have_content(
          strip_tags(
            t(
              'account_reset.confirm_delete_account.info_html',
              email: user_email,
              link: t('account_reset.confirm_delete_account.link_text'),
            ),
          ),
        )
        expect(page).to have_current_path(account_reset_confirm_delete_account_path)
        expect(User.where(id: user.id)).to be_empty
        deleted_user = DeletedUser.find_by(user_id: user.id)
        expect(deleted_user.user_id).to eq(user.id)
        expect(deleted_user.uuid).to eq(user.uuid)
        expect(last_email.subject).to eq t('user_mailer.account_reset_complete.subject')

        click_link t('account_reset.confirm_delete_account.link_text')

        expect(page).to have_current_path(sign_up_email_path)
      end
    end

    it 'sends push notifications if push_notifications_enabled is true' do
      service_provider = build(:service_provider, issuer: 'urn:gov:gsa:openidconnect:test')
      identity = IdentityLinker.new(user, service_provider).link_identity
      agency_identity = AgencyIdentityLinker.new(identity).link_identity

      signin(user_email, user.password)
      click_link t('two_factor_authentication.login_options_link_text')
      click_link t('two_factor_authentication.account_reset.link')
      click_button t('account_reset.request.yes_continue')

      expect(page).
        to have_content strip_tags(
          t('account_reset.confirm_request.instructions_start'),
        )
      expect(page).
        to have_content user_email
      expect(page).
        to have_content strip_tags(
          t('account_reset.confirm_request.instructions_end'),
        )
      expect(page).to have_content t('account_reset.confirm_request.security_note')
      expect(page).to have_content t('account_reset.confirm_request.close_window')

      reset_email

      allow(IdentityConfig.store).to receive(:push_notifications_enabled).and_return(true)
      travel_to(2.days.from_now + 1) do
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

        AccountReset::GrantRequestsAndSendEmails.new.perform(Time.zone.today)
        open_last_email
        click_email_link_matching(/delete_account\?token/)

        expect(page).to have_content(t('account_reset.delete_account.title'))
        expect(page).to have_current_path(account_reset_delete_account_path)

        click_button t('account_reset.request.yes_continue')

        expect(request).to have_been_requested
      end
    end
  end

  context 'as an IAL1 user without a phone' do
    let(:user) { create(:user, :with_backup_code, :with_authentication_app) }

    it 'does not tell the user that an SMS was sent to their registered phone' do
      signin(user_email, user.password)
      click_link t('two_factor_authentication.login_options_link_text')
      click_link t('two_factor_authentication.account_reset.link')
      click_button t('account_reset.request.yes_continue')

      expect(page).
        to have_content strip_tags(
          t('account_reset.confirm_request.instructions_start'),
        )
      expect(page).
        to have_content user_email
      expect(page).
        to have_content strip_tags(
          t('account_reset.confirm_request.instructions_end'),
        )
      expect(page).to_not have_content t('account_reset.confirm_request.security_note')
      expect(page).to have_content t('account_reset.confirm_request.close_window')

      # user should now be signed out
      visit account_path

      expect(page).to have_current_path(new_user_session_path)
    end
  end

  context 'as an IAL2 user' do
    let(:user) do
      create(
        :profile,
        :active,
        :verified,
        pii: { first_name: 'John', ssn: '111223333' },
      ).user
    end

    it 'does allow the user to delete their account from 2FA screen' do
      signin(user_email, user.password)
      click_link t('two_factor_authentication.login_options_link_text')

      # Visiting account reset directly should redirect to 2FA
      visit account_reset_recovery_options_path

      expect(page.current_path).to eq(account_reset_recovery_options_path)
    end
  end
end
