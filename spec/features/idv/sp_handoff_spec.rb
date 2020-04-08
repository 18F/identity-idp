require 'rails_helper'

feature 'IdV SP handoff', :email do
  include SamlAuthHelper
  include IdvStepHelper

  context 'with oidc' do
    it_behaves_like 'sp handoff after identity verification', :oidc
  end

  context 'with saml' do
    it_behaves_like 'sp handoff after identity verification', :saml
  end
end
