require 'rails_helper'

feature 'idv usps otp verification step' do
  include IdvStepHelper

  it_behaves_like 'usps otp verfication step'
  it_behaves_like 'usps otp verfication step', :oidc
  it_behaves_like 'usps otp verfication step', :saml
end
