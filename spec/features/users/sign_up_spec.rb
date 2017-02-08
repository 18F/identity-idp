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

  context 'with js', js: true do
    context 'sp loa1' do
      it 'allows the user to toggle the modal' do
        sign_up_with_sp
        expect(page).to have_xpath("//div[@id='sp-loa-cancel'][@class='hide']")

        click_on t('links.cancel')
        expect(page).to have_xpath("//div[@id='sp-loa-cancel']")

        click_on t('loa1.buttons.continue')
        expect(page).to have_xpath("//div[@id='sp-loa-cancel'][@class='hide']")
      end

      it 'allows the user to delete their account and returns them to the home page' do
        user = sign_up_with_sp
        click_on t('links.cancel')

        click_on t('loa1.buttons.cancel')

        expect(page).to have_content t('loa1.cancel.success')
        expect(page).to have_content(t('headings.sign_in_with_sp',
                                       sp: 'Your friendly Government Agency'))
        sign_in_user(user)

        expect(page).to have_content t('devise.failure.invalid')
      end
    end

    context 'sp loa3' do
      it 'behaves like loa1 when user has not finished sign up' do
        sign_up_with_sp(loa: 'loa3')

        click_on t('links.cancel')

        expect(page).to have_xpath("//input[@value=\"#{t('loa1.buttons.cancel')}\"]")
      end
    end
  end
end
