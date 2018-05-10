require 'rails_helper'

feature 'idv profile step', :idv_job do
  include IdvStepHelper

  context 'with valid information' do
    it 'requires the user to complete to continue to the address step and is not re-entrant' do
      start_idv_from_sp
      complete_idv_steps_before_profile_step

      # Try to skip ahead to address step
      visit idv_address_path

      # Get redirected to the profile step
      expect(page).to have_current_path(idv_session_path)

      # Complete the idv form
      fill_out_idv_form_ok
      click_idv_continue

      # Expect to be on the address step
      expect(page).to have_content(t('idv.titles.select_verification'))
      expect(page).to have_current_path(idv_address_path)

      # Attempt to go back to profile step
      visit idv_session_path

      # Get redirected to the address step
      expect(page).to have_content(t('idv.titles.select_verification'))
      expect(page).to have_current_path(idv_address_path)
    end
  end

  context 'cancelling IdV' do
    it_behaves_like 'cancel at idv step', :profile
    it_behaves_like 'cancel at idv step', :profile, :oidc
    it_behaves_like 'cancel at idv step', :profile, :saml
  end

  context "when the user's information cannot be verified" do
    it_behaves_like 'fail to verify idv info', :profile
  end

  context 'when the IdV background job fails' do
    it_behaves_like 'failed idv job', :profile
  end

  context 'after the max number of attempts' do
    it_behaves_like 'verification step max attempts', :profile
    it_behaves_like 'verification step max attempts', :profile, :oidc
    it_behaves_like 'verification step max attempts', :profile, :saml
  end
end
