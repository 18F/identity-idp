require 'rails_helper'

feature 'IdV SP handoff', :idv_job, :email do
  include SamlAuthHelper
  include IdvHelper

  context 'with oidc' do
    it_behaves_like 'sp handoff after identity verification', :oidc
  end

  context 'with saml' do
    it_behaves_like 'sp handoff after identity verification', :saml
  end
end
