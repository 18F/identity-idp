require 'rails_helper'

describe 'LOA3 account creation' do
  include IdvHelper
  include SamlAuthHelper

  it_behaves_like 'creating an LOA3 account using authenticator app for 2FA', :saml
  it_behaves_like 'creating an LOA3 account using authenticator app for 2FA', :oidc
end
