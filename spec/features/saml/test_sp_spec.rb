require 'rails_helper'

feature 'Test SP' do
  let(:user) { create(:user, :signed_up) }

  context 'visiting /test/saml' do
    scenario 'adds acs_url domain names for current Rails env to CSP form_action' do
      sign_in_and_2fa_user(user)
      visit '/test/saml'

      expect(page.response_headers['Content-Security-Policy']).
        to include('form-action \'self\' localhost:3000 example.com')
    end
  end
end
