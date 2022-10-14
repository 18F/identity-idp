require 'rails_helper'

feature 'managing email address' do
  context 'show one email address if only one is configured' do
    scenario 'shows one email address for a user with only one' do
      user = create(:user, :signed_up, :with_multiple_emails)
      sign_in_and_2fa_user(user)

      expect(page).to have_content(user.email_addresses.first.email)
    end

    scenario 'shows all email address for a user with multiple emails' do
      user = create(:user, :signed_up, :with_multiple_emails)
      email1, email2 = user.reload.email_addresses.map(&:email)
      sign_in_and_2fa_user(user)

      expect(page).to have_content(email1)
      expect(page).to have_content(email2)
    end

    scenario 'does not show a unconfirmed email with a expired confirmation period' do
      user = create(:user, :signed_up)
      confirmed_email = user.reload.email_addresses.first.email

      expired_unconfirmed_email_address = create(
        :email_address,
        user: user,
        confirmed_at: nil,
        confirmation_sent_at: 36.hours.ago,
      )
      expired_unconfirmed_email = expired_unconfirmed_email_address.email

      sign_in_and_2fa_user(user)

      expect(page).to have_content(confirmed_email)
      expect(page).to_not have_content(expired_unconfirmed_email)
    end
  end

  context 'allows deletion of email address' do
    it 'does not allow last confirmed email to be deleted' do
      user = create(:user, :signed_up, email: 'test@example.com ')
      confirmed_email = user.confirmed_email_addresses.first
      unconfirmed_email = create(:email_address, user: user, confirmed_at: nil)
      user.email_addresses.reload

      sign_in_and_2fa_user(user)
      expect(page).to have_current_path(account_path)

      delete_link_not_displayed(confirmed_email)
      delete_link_is_displayed(unconfirmed_email)

      delete_email_should_fail(confirmed_email)
      delete_email_should_not_fail(unconfirmed_email)
    end

    it 'Allows delete when more than one confirmed email exists' do
      user = create(:user, :signed_up, email: 'test@example.com ')
      confirmed_email1 = user.confirmed_email_addresses.first
      confirmed_email2 = create(
        :email_address, user: user,
                        confirmed_at: Time.zone.now
      )
      user.email_addresses.reload

      sign_in_and_2fa_user(user)
      expect(page).to have_current_path(account_path)

      delete_link_is_displayed(confirmed_email1)
      delete_link_is_displayed(confirmed_email2)

      delete_email_should_not_fail(confirmed_email1)
    end

    it 'sends notification to all confirmed emails when email address is deleted' do
      user = create(:user, :signed_up, email: 'test@example.com ')
      confirmed_email1 = user.confirmed_email_addresses.first
      confirmed_email2 = create(:email_address, user: user, confirmed_at: Time.zone.now)

      sign_in_and_2fa_user(user)
      expect(page).to have_current_path(account_path)
      delete_email_should_not_fail(confirmed_email1)

      expect_delivered_email_count(2)
      expect_delivered_email(
        0, {
          to: [confirmed_email1.email],
          subject: t('user_mailer.email_deleted.subject'),
        }
      )
      expect_delivered_email(
        1, {
          to: [confirmed_email2.email],
          subject: t('user_mailer.email_deleted.subject'),
        }
      )
    end

    it 'allows a user to create an account with the old email address' do
      user = create(:user, :signed_up)
      original_email = user.email
      original_email_address = user.email_addresses.first
      create(:email_address, user: user)

      sign_in_and_2fa_user(user)

      visit manage_email_confirm_delete_url(id: original_email_address.id)
      click_button t('forms.email.buttons.delete')

      Capybara.reset_session!

      sign_up_with(original_email)
      open_last_email
      click_email_link_matching(/confirmation_token/)
      expect(page).to have_content(t('devise.confirmations.confirmed'))
    end

    def delete_link_not_displayed(email)
      delete_link_path = manage_email_confirm_delete_url(id: email.id)
      expect(page).to_not have_link(t('forms.buttons.delete'), href: delete_link_path)
    end

    def delete_link_is_displayed(email)
      delete_link_path = manage_email_confirm_delete_url(id: email.id)
      expect(page).to have_link(t('forms.buttons.delete'), href: delete_link_path)
    end

    def delete_email_should_fail(email)
      visit manage_email_confirm_delete_url(id: email.id)
      expect(page).to have_content t(
        'email_addresses.delete.confirm',
        email: email.email,
      )
      click_button t('forms.email.buttons.delete')

      expect(page).to have_current_path(account_path)
      expect(page).to have_content t('email_addresses.delete.failure')
    end

    def delete_email_should_not_fail(email)
      visit manage_email_confirm_delete_url(id: email.id)
      expect(page).to have_content t(
        'email_addresses.delete.confirm',
        email: email.email,
      )
      click_button t('forms.email.buttons.delete')

      expect(page).to have_current_path(account_path)
      expect(page).to have_content t('email_addresses.delete.success')
    end
  end
end
