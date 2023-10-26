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
  end
end
