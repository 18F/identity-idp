require 'rails_helper'

RSpec.feature 'sp requested IdV attributes', :email do
  context 'oidc' do
    it_behaves_like 'sp requesting attributes', :oidc
  end

  context 'saml' do
    it_behaves_like 'sp requesting attributes', :saml
  end
end
