require 'rails_helper'

RSpec.describe 'IAL2 account creation' do
  include IdvHelper
  include DocAuthHelper
  include SamlAuthHelper
  include WebAuthnHelper

  it_behaves_like 'creating an IAL2 account using authenticator app for 2FA', :saml
  it_behaves_like 'creating an IAL2 account using authenticator app for 2FA', :oidc

  it_behaves_like 'creating an IAL2 account using webauthn for 2FA', :saml
  it_behaves_like 'creating an IAL2 account using webauthn for 2FA', :oidc
end
