require 'rails_helper'

describe 'Account Reset Request: Delete Account', email: true do
  include PushNotificationsHelper

  let(:user) { create(:user, :signed_up) }
  let(:user_email) { user.email_addresses.first.email }
  let(:push_notification_url) { 'http://localhost/push_notifications' }

  context 'as an LOA1 user' do
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

      Timecop.travel(Time.zone.now + 2.days) do
        AccountReset::GrantRequestsAndSendEmails.new.call
        open_last_email
        click_email_link_matching(/delete_account\?token/)

        expect(page).to have_content(t('account_reset.delete_account.title'))
        expect(page).to have_current_path(account_reset_delete_account_path)

        click_button t('account_reset.request.yes_continue')

        expect(page).to have_content(
          strip_tags(
            t(
              'account_reset.confirm_delete_account.info',
              email: user_email,
              link: t('account_reset.confirm_delete_account.link_text'),
            ),
          ),
        )
        expect(page).to have_current_path(account_reset_confirm_delete_account_path)
        expect(User.where(id: user.id)).to be_empty
        expect(last_email.subject).to eq t('user_mailer.account_reset_complete.subject')

        click_link t('account_reset.confirm_delete_account.link_text')

        expect(page).to have_current_path(sign_up_email_path)
      end
    end

    it 'sends push notifications if push_notifications_enabled is true' do
      allow(Figaro.env).to receive(:push_notifications_enabled).and_return('true')
      AgencyIdentity.create(user_id: user.id, agency_id: 1, uuid: '1234')

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

      Timecop.travel(2.days.from_now) do
        request = stub_push_notification_request(
          sp_push_notification_endpoint: push_notification_url,
          topic: 'account_delete',
          payload: {
            'subject' => {
              'subject_type' => 'iss-sub',
              'iss' => 'urn:gov:gsa:openidconnect:test',
              'sub' => '1234',
            },
          },
        )

        AccountReset::GrantRequestsAndSendEmails.new.call
        open_last_email
        click_email_link_matching(/delete_account\?token/)

        expect(page).to have_content(t('account_reset.delete_account.title'))
        expect(page).to have_current_path(account_reset_delete_account_path)

        click_button t('account_reset.request.yes_continue')

        expect(request).to have_been_requested
      end
    end
  end

  context 'as an LOA1 user without a phone' do
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

  context 'as an LOA3 user' do
    let(:user) do
      create(
        :profile,
        :active,
        :verified,
        pii: { first_name: 'John', ssn: '111223333' },
      ).user
    end

    it 'does not allow the user to delete their account from 2FA screen' do
      signin(user_email, user.password)
      click_link t('two_factor_authentication.login_options_link_text')

      # Account reset link should not be present
      expect(page).to_not have_content(t('two_factor_authentication.account_reset.link'))

      # Visiting account reset directly should redirect to 2FA
      visit account_reset_request_path

      expect(page.current_path).to eq(login_two_factor_path(otp_delivery_preference: :sms))
    end
  end
end
