require 'rails_helper'

feature 'Canceling Account Creation' do
  include SamlAuthHelper

  context 'From the enter email page', email: true do
    it 'redirects to the branded start page' do
      authn_request = auth_request.create(saml_settings)
      visit authn_request
      sp_request_id = ServiceProviderRequest.last.uuid
      click_link t('sign_up.registrations.create_account')
      click_link t('links.cancel')

      expect(current_url).to eq sign_up_start_url(request_id: sp_request_id)
    end
  end

  context 'From the enter password page', email: true do
    it 'redirects to the branded start page' do
      authn_request = auth_request.create(saml_settings)
      visit authn_request
      sp_request_id = ServiceProviderRequest.last.uuid
      click_link t('sign_up.registrations.create_account')
      submit_form_with_valid_email
      click_confirmation_link_in_email('test@test.com')
      click_button t('links.cancel_account_creation')

      expect(current_url).to eq sign_up_cancel_url
    end
  end
end
