require 'rails_helper'

describe 'LOA3 account creation' do
  include IdvHelper
  include SamlAuthHelper
  include WebAuthnHelper

  it_behaves_like 'creating an LOA3 account using authenticator app for 2FA', :saml
  it_behaves_like 'creating an LOA3 account using authenticator app for 2FA', :oidc

  it_behaves_like 'creating an LOA3 account using webauthn for 2FA', :saml
  it_behaves_like 'creating an LOA3 account using webauthn for 2FA', :oidc
end
