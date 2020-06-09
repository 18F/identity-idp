require 'rails_helper'

feature 'cac proofing enter info step' do
  include CacProofingHelper

  before do
    sign_in_and_2fa_user
  end

  context 'using a CAC' do
    before do
      complete_cac_proofing_steps_before_enter_info_step
    end

    it 'is on the correct page and does not ask for full name' do
      expect(page).to have_current_path(idv_cac_proofing_enter_info_step)
      expect(page).to_not have_content(t('in_person_proofing.forms.first_name'))
      expect(page).to_not have_content(t('in_person_proofing.forms.last_name'))
    end

    it 'proceeds to the next page with a valid CAC' do
      fill_out_cac_proofing_form_ok
      click_continue

      expect(page).to have_current_path(idv_cac_proofing_verify_step)
    end
  end

  context 'using a PIV' do
    before do
      complete_piv_proofing_steps_before_enter_info_step
    end

    it 'is on the correct page and does ask for full name' do
      expect(page).to have_current_path(idv_cac_proofing_enter_info_step)
      expect(page).to have_content(t('in_person_proofing.forms.first_name'))
      expect(page).to have_content(t('in_person_proofing.forms.last_name'))
    end

    it 'proceeds to the next page with a valid PIV' do
      fill_out_piv_proofing_form_ok
      click_continue

      expect(page).to have_current_path(idv_cac_proofing_verify_step)
    end
  end
end
