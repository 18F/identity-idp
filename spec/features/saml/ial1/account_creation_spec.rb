require 'rails_helper'

feature 'Canceling Account Creation' do
  include SamlAuthHelper

  context 'From the enter email page', email: true do
    it 'redirects to the branded start page' do
      visit saml_authn_request_url
      sp_request_id = ServiceProviderRequestProxy.last.uuid
      click_link t('links.create_account')
      click_link t('links.cancel')

      expect(current_url).to eq new_user_session_url(request_id: sp_request_id)
    end
  end

  context 'From the enter password page', email: true do
    it 'redirects to the branded start page' do
      visit saml_authn_request_url
      click_link t('links.create_account')
      submit_form_with_valid_email
      click_confirmation_link_in_email('test@test.com')
      click_link t('links.cancel_account_creation')

      expect(current_url).to eq sign_up_cancel_url

      expect {
        click_button t('forms.buttons.cancel')
      }.to change(User, :count).by(-1)
      expect(current_url).to eq \
        new_user_session_url(request_id: ServiceProviderRequestProxy.last.uuid)
    end

    it 'redirects to the password page after cancelling the cancellation' do
      visit saml_authn_request_url
      click_link t('links.create_account')
      submit_form_with_valid_email
      click_confirmation_link_in_email('test@test.com')
      previous_url = current_url
      click_link t('links.cancel_account_creation')

      expect(current_url).to eq sign_up_cancel_url
      expect {
        click_link t('links.go_back')
      }.to change(User, :count).by(0)

      expect(current_url).to eq previous_url
    end
  end
end
