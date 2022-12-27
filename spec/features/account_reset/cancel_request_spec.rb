require 'rails_helper'

describe 'Account Reset Request: Cancellation' do
  context 'user cancels from the second email after the request has been granted' do
    it 'cancels the request and does not delete the user', email: true do
      user = create(:user, :signed_up)
      signin(user.email, user.password)
      click_link t('two_factor_authentication.login_options_link_text')
      click_link t('two_factor_authentication.account_reset.link')
      expect(page).
        to have_content strip_tags(
          t('account_reset.recovery_options.try_method_again'),
        )
      click_link t('account_reset.request.yes_continue')
      expect(page).
        to have_content strip_tags(
          t('account_reset.request.delete_account'),
        )
      click_button t('account_reset.request.yes_continue')
      reset_email

      travel_to(Time.zone.now + 2.days + 1) do
        AccountReset::GrantRequestsAndSendEmails.new.perform(Time.zone.today)
        open_last_email
        click_email_link_matching(/cancel\?token/)
        click_button t('account_reset.cancel_request.cancel_button')

        expect(page).to have_current_path new_user_session_path
        expect(page).to have_content(
          t('two_factor_authentication.account_reset.successful_cancel', app_name: APP_NAME),
        )

        signin(user.email, user.password)

        expect(page).
          to have_current_path(
            login_two_factor_path(otp_delivery_preference: 'sms', reauthn: 'false'),
          )
      end
    end
  end
end
