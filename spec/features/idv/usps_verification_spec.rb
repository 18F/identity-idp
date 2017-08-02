require 'rails_helper'

feature 'USPS verification' do
  include SamlAuthHelper
  include IdvHelper

  context 'signing in when profile is pending USPS verification' do
    it_behaves_like 'signing in with pending USPS verification'
    it_behaves_like 'signing in with pending USPS verification', :saml
    it_behaves_like 'signing in with pending USPS verification', :oidc
  end
end
