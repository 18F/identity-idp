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

    scenario 'Does not allow delete when only one email exists' do
      user = create(:user, :with_email, email: 'test@example.com ')
      email_id = user.reload.email_addresses.first.id
      sign_in_and_2fa_user(user)

      delete_link_path = manage_email_confirm_delete_url(id: email_id)
      expect(page).to_not have_content delete_link_path
    end

    scenario 'Allows delete when more than one email exists' do
      user = create(:user, :signed_up, :with_multiple_emails)
      email_2_id, email_1_id = user.reload.email_addresses.map(&:id)
      email2, email1 = user.reload.email_addresses.map(&:email)
      delete_link_path1 = manage_email_confirm_delete_url(id: email_1_id)
      delete_link_path2 = manage_email_confirm_delete_url(id: email_2_id)

      sign_in_and_2fa_user(user)

      expect(page).to have_content(email1)
      expect(page).to have_content(email2)

      expect(page).to have_link(t('forms.buttons.delete'), href: delete_link_path1)
      expect(page).to have_link(t('forms.buttons.delete'), href: delete_link_path2)

      find("a[href='#{delete_link_path1}']").click

      expect(page).to have_content t('email_addresses.delete.confirm', email: email1)

      click_button t('forms.email.buttons.delete')

      expect(page).to_not have_content(email1)
      expect(page).to have_content(email2)
    end
  end
end
