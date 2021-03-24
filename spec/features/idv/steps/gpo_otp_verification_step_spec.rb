require 'rails_helper'

feature 'idv gpo otp verification step' do
  include IdvStepHelper

  it_behaves_like 'gpo otp verfication step'
  it_behaves_like 'gpo otp verfication step', :oidc
  it_behaves_like 'gpo otp verfication step', :saml

  context 'with GPO proofing disabled it still lets users with a letter verify' do
    it_behaves_like 'gpo otp verfication step'
    it_behaves_like 'gpo otp verfication step', :oidc
    it_behaves_like 'gpo otp verfication step', :saml
  end
end
