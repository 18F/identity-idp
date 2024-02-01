require 'rails_helper'

RSpec.feature 'user interacts with 2FA across multiple browser tabs',
              allowed_extra_analytics: [:*] do
  include SpAuthHelper
  include SamlAuthHelper

  it_behaves_like 'visiting 2fa when fully authenticated', :oidc
  it_behaves_like 'visiting 2fa when fully authenticated', :saml
end
