require 'rails_helper'

RSpec.feature 'Canceling Account Creation' do
  include SamlAuthHelper

  context 'From the enter email page', email: true do
    it 'redirects to the branded start page' do
      visit saml_authn_request_url
      sp_request_id = ServiceProviderRequestProxy.last.uuid
      click_link t('links.create_account')
      click_link t('links.cancel')

      expect(page).to have_current_path(new_user_session_path(request_id: sp_request_id))
    end
  end

  context 'From the enter password page', email: true do
    it 'redirects to the branded start page' do
      visit saml_authn_request_url
      click_link t('links.create_account')
      submit_form_with_valid_email
      click_confirmation_link_in_email('test@test.com')
      click_link t('links.cancel_account_creation')

      expect(page).to have_current_path(sign_up_cancel_path)

      expect do
        click_button t('forms.buttons.cancel')
      end.to change(User, :count).by(-1)
      expect(page).to have_current_path(
        new_user_session_path(request_id: ServiceProviderRequestProxy.last.uuid),
      )
    end

    it 'redirects to the password page after cancelling the cancellation' do
      visit saml_authn_request_url
      click_link t('links.create_account')
      submit_form_with_valid_email
      click_confirmation_link_in_email('test@test.com')
      previous_url = current_url
      click_link t('links.cancel_account_creation')

      expect(page).to have_current_path(sign_up_cancel_path)
      expect do
        click_link t('links.go_back')
      end.to change(User, :count).by(0)

      expect(page).to have_current_path(previous_url, url: true)
    end
  end
end
