require 'rails_helper'

feature 'account creation across multiple browsers' do
  include SpAuthHelper
  include SamlAuthHelper

  it_behaves_like 'creating two accounts during the same session', :oidc
  it_behaves_like 'creating two accounts during the same session', :saml
end
