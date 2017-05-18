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
end
