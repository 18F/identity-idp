require 'rails_helper'

feature 'user interacts with 2FA across multiple browser tabs' do
  include SpAuthHelper
  include SamlAuthHelper

  it_behaves_like 'visiting 2fa when fully authenticated', :oidc
  it_behaves_like 'visiting 2fa when fully authenticated', :saml
end
