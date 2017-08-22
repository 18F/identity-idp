require 'rails_helper'

feature 'account creation after LOA3 request', idv_job: true do
  include SamlAuthHelper
  include IdvHelper

  context 'successful IdV with same phone as 2FA' do
    it_behaves_like 'idv account creation', :saml
    it_behaves_like 'idv account creation', :oidc
  end

  context 'choosing USPS address verification' do
    it_behaves_like 'selecting usps address verification method', :saml
    it_behaves_like 'selecting usps address verification method', :oidc
  end
end
