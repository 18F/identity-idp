require 'rails_helper'

feature 'cancel at IdV step', :idv_job do
  include IdvStepHelper

  context 'verify step' do
    it_behaves_like 'cancel at idv step', :verify
    it_behaves_like 'cancel at idv step', :verify, :oidc
    it_behaves_like 'cancel at idv step', :verify, :saml
  end

  context 'profile step' do
    it_behaves_like 'cancel at idv step', :profile
    it_behaves_like 'cancel at idv step', :profile, :oidc
    it_behaves_like 'cancel at idv step', :profile, :saml
  end

  context 'phone otp verification step' do
    it_behaves_like 'cancel at idv step', :phone_otp_verification
    it_behaves_like 'cancel at idv step', :phone_otp_verification, :oidc
    it_behaves_like 'cancel at idv step', :phone_otp_verification, :saml
  end

  xcontext 'usps step' do
    # USPS step does not have a cancel button :(
  end
end
