require 'rails_helper'

feature 'cancel at IdV step', :idv_job do
  include IdvStepHelper

  context 'verify step' do
    def complete_previous_idv_steps
      sign_in_and_2fa_user(user_with_2fa)
      visit verify_path unless current_path == verify_path
    end

    it_behaves_like 'cancel at idv step'
    it_behaves_like 'cancel at idv step', :oidc
    it_behaves_like 'cancel at idv step', :saml
  end

  context 'profile step' do
    alias complete_previous_idv_steps start_idv_at_profile_step

    it_behaves_like 'cancel at idv step'
    it_behaves_like 'cancel at idv step', :oidc
    it_behaves_like 'cancel at idv step', :saml
  end

  context 'address step' do
    alias complete_previous_idv_steps complete_idv_steps_before_address_step

    it_behaves_like 'cancel at idv step'
    it_behaves_like 'cancel at idv step', :oidc
    it_behaves_like 'cancel at idv step', :saml
  end

  xcontext 'phone step' do
    alias complete_previous_idv_steps complete_idv_steps_before_phone_step
    # Phone step doesn't have a cancel button :(
  end

  xcontext 'phone otp delivery method selection step' do
    alias complete_previous_idv_steps complete_idv_steps_before_phone_otp_delivery_selection_step
    # Phone OTP delivery method step doesn't have a cancel button :(
  end

  context 'phone OTP verification step' do
    alias complete_previous_idv_steps complete_idv_steps_before_phone_otp_verification_step

    it_behaves_like 'cancel at idv step'
    it_behaves_like 'cancel at idv step', :oidc
    it_behaves_like 'cancel at idv step', :saml
  end

  xcontext 'usps step' do
    alias complete_previous_idv_steps complete_idv_steps_before_usps_step
    # USPS step does not have a cancel button :(
  end
end
