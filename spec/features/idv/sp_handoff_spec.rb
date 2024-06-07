require 'rails_helper'

RSpec.feature 'IdV SP handoff', :email, allowed_extra_analytics: [:*] do
  include SamlAuthHelper
  include IdvStepHelper

  context 'with oidc' do
    it_behaves_like 'sp handoff after identity verification', :oidc
  end

  context 'with saml' do
    it_behaves_like 'sp handoff after identity verification', :saml
  end
end
