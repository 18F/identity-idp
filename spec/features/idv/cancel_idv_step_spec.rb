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

  xcontext 'usps step' do
    # USPS step does not have a cancel button :(
  end
end
