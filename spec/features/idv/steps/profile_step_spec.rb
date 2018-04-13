require 'rails_helper'

feature 'idv profile step', :idv_job do
  include IdvStepHelper

  context 'with valid information' do
    it 'allows the user to continue to the address step' do
      start_idv_from_sp
      complete_idv_steps_before_profile_step
      fill_out_idv_form_ok
      click_idv_continue

      expect(page).to have_content(t('idv.titles.select_verification'))
      expect(page).to have_current_path(verify_address_path)
    end
  end

  context 'after submitting valid information' do
    it 'is not re-entrant' do
      start_idv_from_sp
      complete_idv_steps_before_profile_step
      fill_out_idv_form_ok
      click_idv_continue

      # Attempt to go back to profile step
      visit verify_session_path

      # Get redirected to the address step
      expect(page).to have_content(t('idv.titles.select_verification'))
      expect(page).to have_current_path(verify_address_path)
    end
  end

  it 'does not allow the user to advance without completing' do
    start_idv_from_sp
    complete_idv_steps_before_profile_step

    # Try to skip ahead to address step
    visit verify_address_path

    # Get redirect to the profile step
    expect(page).to have_current_path(verify_session_path)
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
