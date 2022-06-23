require 'rails_helper'

feature 'idv gpo otp verification step', :js do
  include IdvStepHelper

  it_behaves_like 'gpo otp verification step'
  it_behaves_like 'gpo otp verification step', :oidc
  it_behaves_like 'gpo otp verification step', :saml

  context 'with GPO proofing disabled it still lets users with a letter verify' do
    it_behaves_like 'gpo otp verification step'
    it_behaves_like 'gpo otp verification step', :oidc
    it_behaves_like 'gpo otp verification step', :saml
  end
end
