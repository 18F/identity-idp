require 'rails_helper'

feature 'sp requested IdV attributes', :idv_job, :email do
  context 'oidc' do
    it_behaves_like 'sp requesting attributes', :oidc
  end

  context 'saml' do
    it_behaves_like 'sp requesting attributes', :saml
  end
end
