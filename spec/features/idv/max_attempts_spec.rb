require 'rails_helper'

feature 'IdV max attempts', :idv_job, :email do
  include IdvStepHelper
  include JavascriptDriverHelper

  context 'profile step' do
    it_behaves_like 'verification step max attempts', :profile
    it_behaves_like 'verification step max attempts', :profile, :oidc
    it_behaves_like 'verification step max attempts', :profile, :saml
  end
end
