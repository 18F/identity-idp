require 'rails_helper'

feature 'idv profile step', :idv_job do
  include IdvStepHelper

  context 'with valid information' do
    before do
      start_idv_from_sp
    end

    it 'populates the state from the jurisdiction selection' do
      complete_idv_steps_before_jurisdiction_step

      abbrev = 'WA'
      state = 'Washington'
      select state, from: 'jurisdiction_state'
      click_idv_continue

      expect(page).to have_selector("option[selected='selected'][value='#{abbrev}']")
    end

    it 'requires the user to complete to continue to the address step and is not re-entrant' do
      complete_idv_steps_before_profile_step

      # Try to skip ahead to address step
      visit idv_address_path

      # Get redirected to the profile step
      expect(page).to have_current_path(idv_session_path)

      # Complete the idv form
      fill_out_idv_form_ok
      click_idv_continue

      # Expect to be on the success step
      expect(page).to have_content(t('idv.titles.session.success'))
      expect(page).to have_current_path(idv_session_success_path)

      # Attempt to go back to profile step
      visit idv_session_path

      # Get redirected to the success step
      expect(page).to have_content(t('idv.titles.session.success'))
      expect(page).to have_current_path(idv_session_success_path)

      # Then continue to the address step
      click_idv_continue

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

    context 'after the warning modal is dismissed' do
      let(:state) { 'Washington' }
      let(:abbrev) { 'WA' }

      before do
        start_idv_from_sp
        complete_idv_steps_before_profile_step
        fill_out_idv_form_fail(state: state)
        click_continue
        click_button t('idv.modal.button.warning')
      end

      it 'populates the state from the form' do
        expect(page).to have_selector("option[selected='selected'][value='#{abbrev}']")
      end
    end
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
