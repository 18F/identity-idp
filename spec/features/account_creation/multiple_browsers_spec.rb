require 'rails_helper'

RSpec.feature 'account creation across multiple browsers' do
  include SpAuthHelper
  include SamlAuthHelper
  include OidcAuthHelper

  it_behaves_like 'creating two accounts during the same session', :oidc
  it_behaves_like 'creating two accounts during the same session', :saml
end
