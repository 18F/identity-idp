require 'rails_helper'

feature 'account creation after LOA3 request', idv_job: true do
  include SamlAuthHelper
  include IdvHelper

  context 'choosing USPS address verification' do
    it_behaves_like 'selecting usps address verification method', :saml
    it_behaves_like 'selecting usps address verification method', :oidc
  end

  context 'choosing phone address verification otp delivery method' do
    it_behaves_like 'idv otp delivery method selection', :saml
    it_behaves_like 'idv otp delivery method selection', :oidc
  end

  context 'entering state id data' do
    it_behaves_like 'idv state id data entry', :saml
    it_behaves_like 'idv state id data entry', :oidc
  end
end
