require 'rails_helper'

feature 'Sign Up' do
  context 'confirmation token error message does not persist on success' do
    scenario 'with no or invalid token' do
      visit sign_up_create_email_confirmation_url(confirmation_token: '')
      expect(page).to have_content t('errors.messages.confirmation_invalid_token')

      sign_up

      expect(page).not_to have_content t('errors.messages.confirmation_invalid_token')
    end
  end

  context 'user cancels sign up on email screen' do
    before do
      visit sign_up_email_path
      page.find('#auth-flow-cancel').click
    end

    it 'redirects user to the home page' do
      expect(current_path).to eq(root_path)
    end

    it 'redirects to the homepage from the modal', js: true do
      page.find('a', text: t('links.cancel_account_creation')).click
      expect(current_path).to eq(root_path)
    end
  end

  context 'with js', js: true do
    context 'sp loa1' do
      it 'allows the user to toggle the modal' do
        begin_sign_up_with_sp_and_loa(loa3: false)
        expect(page).not_to have_xpath("//div[@id='cancel-action-modal']")

        click_on t('links.cancel')
        expect(page).to have_xpath("//div[@id='cancel-action-modal']")

        click_on t('sign_up.buttons.continue')
        expect(page).not_to have_xpath("//div[@id='cancel-action-modal']")
      end

      it 'allows the user to delete their account and returns them to the home page' do
        user = begin_sign_up_with_sp_and_loa(loa3: false)

        click_on t('links.cancel')
        click_on t('sign_up.buttons.cancel')

        expect(page).to have_content t('sign_up.cancel.success')
        expect { User.find(user.id) }.to raise_error ActiveRecord::RecordNotFound
      end
    end

    context 'sp loa3' do
      it 'behaves like loa1 when user has not finished sign up' do
        begin_sign_up_with_sp_and_loa(loa3: true)

        click_on t('links.cancel')

        expect(page).to have_xpath("//input[@value=\"#{t('sign_up.buttons.cancel')}\"]")
      end
    end
  end
end
