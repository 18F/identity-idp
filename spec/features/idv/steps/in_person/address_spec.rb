require 'rails_helper'

RSpec.describe 'doc auth In person proofing residential address step', js: true do
  include IdvStepHelper
  include InPersonHelper

  before do
    allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
    allow(IdentityConfig.store).to receive(:in_person_residential_address_controller_enabled).
      and_return(true)
  end

  context 'when visiting address for the first time' do
    it 'displays correct heading and button text', allow_browser_log: true do
      complete_idv_steps_before_address
      # residential address page
      expect(page).to have_current_path(idv_in_person_proofing_address_url)

      expect(page).to have_content(t('forms.buttons.continue'))
      expect(page).to have_content(t('in_person_proofing.headings.address'))
    end

    it 'allows the user to cancel and start over', allow_browser_log: true do
      complete_idv_steps_before_address

      expect(page).not_to have_content('forms.buttons.back')

      click_link t('links.cancel')
      click_on t('idv.cancel.actions.start_over')
      expect(page).to have_current_path(idv_welcome_path)
    end

    it 'allows the user to cancel and return', allow_browser_log: true do
      complete_idv_steps_before_address

      expect(page).not_to have_content('forms.buttons.back')

      click_link t('links.cancel')
      click_on t('idv.cancel.actions.keep_going')
      expect(page).to have_current_path(idv_in_person_proofing_address_url)
    end

    it 'allows user to submit valid inputs on form', allow_browser_log: true do
      user = user_with_2fa
      complete_idv_steps_before_address(user)
      fill_out_address_form_ok
      click_idv_continue

      expect(page).to have_current_path(idv_in_person_ssn_url, wait: 10)
      complete_ssn_step(user)

      expect_in_person_step_indicator_current_step(t('step_indicator.flows.idv.verify_info'))
      expect(page).to have_current_path(idv_in_person_verify_info_url)
      expect(page).to have_text(InPersonHelper::GOOD_ADDRESS1)
      expect(page).to have_text(InPersonHelper::GOOD_ADDRESS2)
      expect(page).to have_text(InPersonHelper::GOOD_CITY)
      expect(page).to have_text(InPersonHelper::GOOD_ZIPCODE)

      go_back
      go_back
      expect(page).to have_current_path(idv_in_person_proofing_address_url)
    end
  end
end
