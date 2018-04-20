require 'rails_helper'

feature 'cancel at IdV step', :idv_job do
  include IdvStepHelper

  context 'phone otp verification step' do
    it_behaves_like 'cancel at idv step', :phone_otp_verification
    it_behaves_like 'cancel at idv step', :phone_otp_verification, :oidc
    it_behaves_like 'cancel at idv step', :phone_otp_verification, :saml
  end

  xcontext 'usps step' do
    # USPS step does not have a cancel button :(
  end
end
