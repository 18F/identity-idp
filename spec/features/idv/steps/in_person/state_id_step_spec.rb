require 'rails_helper'

RSpec.describe 'doc auth IPP state ID step', js: true do
  include IdvStepHelper
  include InPersonHelper

  before do
    allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
  end

  context 'capture secondary id is enabled' do
    before do
      allow(IdentityConfig.store).
        to(receive(:in_person_capture_secondary_id_enabled)).
        and_return(true)
    end

    it 'validates zip code input', allow_browser_log: true do
      user = user_with_2fa

      sign_in_and_2fa_user(user)
      begin_in_person_proofing(user)
      complete_prepare_step(user)
      complete_location_step(user)
      expect(page).to have_current_path(idv_in_person_step_path(step: :state_id), wait: 10)
      fill_out_state_id_form_ok(same_address_as_id: true, capture_secondary_id_enabled: true)
      # blank out the zip code field
      fill_in t('in_person_proofing.form.state_id.zipcode'), with: ''
      # try to enter invalid input into the zip code field
      fill_in t('in_person_proofing.form.state_id.zipcode'), with: 'invalid input'
      expect(page).to have_field(t('in_person_proofing.form.state_id.zipcode'), with: '')
      # enter valid characters, but invalid length
      fill_in t('in_person_proofing.form.state_id.zipcode'), with: '123'
      click_idv_continue
      expect(page).to have_css('.usa-error-message', text: t('idv.errors.pattern_mismatch.zipcode'))
      # enter a valid zip and make sure we can continue
      fill_in t('in_person_proofing.form.state_id.zipcode'), with: '123456789'
      expect(page).to have_field(t('in_person_proofing.form.state_id.zipcode'), with: '12345-6789')
      click_idv_continue
      expect(page).to have_current_path(idv_in_person_ssn_url)
    end
  end
end
