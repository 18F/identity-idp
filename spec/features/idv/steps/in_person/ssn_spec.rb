require 'rails_helper'

RSpec.describe 'doc auth IPP ssn step', js: true do
  include IdvStepHelper
  include InPersonHelper

  before do
    allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
    allow(IdentityConfig.store).to receive(:in_person_capture_secondary_id_enabled).and_return(true)
  end

  context 'when visiting ssn for the first time' do
    it 'displays correct heading and button text', allow_browser_log: true do
      complete_idv_steps_before_ssn
      # ssn page
      expect(page).to have_content(t('forms.buttons.continue'))
      expect(page).to have_content(t('doc_auth.headings.ssn'))
    end

    it 'allows the user to cancel and start over', allow_browser_log: true do
      user = user_with_2fa
      complete_idv_steps_before_ssn(user)

      expect(page).not_to have_content('forms.buttons.back')

      click_link t('links.cancel')
      click_on t('idv.cancel.actions.start_over')
      expect(page).to have_current_path(idv_welcome_path)
    end

    it 'proceeds to the next page with valid info', allow_browser_log: true do
      user = user_with_2fa
      complete_idv_steps_before_ssn(user)
      # ssn page
      complete_ssn_step(user)

      # verify page (next page)
      expect_in_person_step_indicator_current_step(t('step_indicator.flows.idv.verify_info'))
      expect(page).to have_content(t('headings.verify'))
      expect(page).to have_text(DocAuthHelper::GOOD_SSN_MASKED)
    end
  end

  context 'when visiting ssn again' do
    it 'displays correct heading and button text', allow_browser_log: true do
      user = user_with_2fa
      complete_idv_steps_before_ssn(user)
      # ssn page (first visit)
      complete_ssn_step(user)
      # verify page (next page)
      expect_in_person_step_indicator_current_step(t('step_indicator.flows.idv.verify_info'))
      expect(page).to have_content(t('headings.verify'))
      # click update ssn button on verify page
      click_on t('idv.buttons.change_ssn_label')

      # visting ssn again
      expect(page).to have_content(t('doc_auth.headings.ssn_update'))
      expect(page).to have_content(t('forms.buttons.submit.update'))
    end

    it 'allows the user to go back to the previous page', allow_browser_log: true do
      user = user_with_2fa
      complete_idv_steps_before_ssn(user)
      ## ssn page (first visit)
      complete_ssn_step(user)
      # verify page
      expect_in_person_step_indicator_current_step(t('step_indicator.flows.idv.verify_info'))
      expect(page).to have_content(t('headings.verify'))
      # click update ssn button on verify page
      click_on t('idv.buttons.change_ssn_label')
      # ssn page (visting again)

      expect(page).not_to have_content('idv.cancel.actions.start_over')

      # click back on snn page
      click_on t('forms.buttons.back')

      # verify page (previous page)
      expect_in_person_step_indicator_current_step(t('step_indicator.flows.idv.verify_info'))
      expect(page).to have_content(t('headings.verify'))
    end

    it 'proceeds to the next page with valid info', allow_browser_log: true do
      user = user_with_2fa
      complete_idv_steps_before_ssn(user)
      # ssn page (first visit)
      complete_ssn_step(user)
      # verify page (next page)
      expect_in_person_step_indicator_current_step(t('step_indicator.flows.idv.verify_info'))
      expect(page).to have_content(t('headings.verify'))
      # click update ssn button on verify page
      click_on t('idv.buttons.change_ssn_label')
      # ssn page (visting again)
      fill_out_ssn_form_ok
      click_idv_update

      # verify page (next page)
      expect_in_person_step_indicator_current_step(t('step_indicator.flows.idv.verify_info'))
      expect(page).to have_content(t('headings.verify'))
      expect(page).to have_text(DocAuthHelper::GOOD_SSN_MASKED)
    end
  end

  context 'when in_person_capture_secondary_id_enabled is true, ssn step is accessible from' do
    it 'address step', allow_browser_log: true do
      user = user_with_2fa
      sign_in_and_2fa_user(user)
      begin_in_person_proofing(user)
      # prepare page
      complete_prepare_step(user)
      # location page
      complete_location_step(user)
      # state ID page
      fill_out_state_id_form_ok(
        double_address_verification: true, same_address_as_id: false,
        capture_secondary_id_enabled: true
      )
      click_idv_continue
      fill_out_address_form_ok(double_address_verification: true, same_address_as_id: false)
      click_idv_continue
      # ssn page
      expect(page).to have_content(t('doc_auth.headings.ssn'))
    end

    it 'state_id step (when state id address matches residential address)',
       allow_browser_log: true do
      user = user_with_2fa
      complete_idv_steps_before_ssn(user)
      # ssn page
      expect(page).to have_content(t('doc_auth.headings.ssn'))
    end

    it 'verify info step', allow_browser_log: true do
      user = user_with_2fa
      complete_idv_steps_before_ssn(user)
      # ssn page (first visit)
      complete_ssn_step(user)
      # verify page (next page)
      expect_in_person_step_indicator_current_step(t('step_indicator.flows.idv.verify_info'))
      expect(page).to have_content(t('headings.verify'))
      # click update ssn button on verify page
      click_on t('idv.buttons.change_ssn_label')

      # visting ssn again
      expect(page).to have_content(t('doc_auth.headings.ssn_update'))
    end
  end
end
