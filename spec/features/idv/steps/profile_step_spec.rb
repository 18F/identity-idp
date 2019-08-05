require 'rails_helper'

feature 'idv profile step' do
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
      page.find('label[for=jurisdiction_ial2_consent_given]').click
      click_idv_continue

      expect(page).to have_selector("option[selected='selected'][value='#{abbrev}']")
    end

    it 'requires the user to complete to continue to the address step and is not re-entrant' do
      complete_idv_steps_before_profile_step

      # Try to skip ahead to phone step
      visit idv_phone_path

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

      # Then continue to the phone step
      click_idv_continue

      expect(page).to have_content(t('idv.titles.session.phone'))
      expect(page).to have_current_path(idv_phone_path)
    end
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
        click_on t('idv.failure.button.warning')
      end

      it 'populates the state from the form' do
        expect(page).to have_selector("option[selected='selected'][value='#{abbrev}']")
      end
    end
  end

  context 'when an account exists with the same SSN' do
    it 'renders a warning and locks the user out after 3 attempts' do
      ssn = '123-45-6789'
      create(:profile, ssn_signature: Pii::Fingerprinter.fingerprint(ssn))

      start_idv_from_sp
      complete_idv_steps_before_profile_step

      2.times do
        fill_out_idv_form_ok
        fill_in :profile_ssn, with: ssn
        click_continue

        expect(page).to have_content(t('idv.failure.sessions.warning'))
        expect(page).to have_current_path(idv_session_failure_path(reason: :warning))

        click_on t('idv.failure.button.warning')
      end

      fill_out_idv_form_ok
      fill_in :profile_ssn, with: ssn
      click_continue

      expect(page).to have_content(strip_tags(t('idv.failure.sessions.fail_html')))
      expect(page).to have_current_path(idv_session_failure_path(reason: :fail))
    end
  end

  context 'cancelling IdV' do
    it_behaves_like 'cancel at idv step', :profile
    it_behaves_like 'cancel at idv step', :profile, :oidc
    it_behaves_like 'cancel at idv step', :profile, :saml
  end

  context 'cancelling IdV after profile success' do
    it_behaves_like 'cancel at idv step', :profile_success
    it_behaves_like 'cancel at idv step', :profile_success, :oidc
    it_behaves_like 'cancel at idv step', :profile_success, :saml
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
