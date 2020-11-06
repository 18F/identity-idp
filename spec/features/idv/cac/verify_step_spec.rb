require 'rails_helper'

feature 'cac proofing verify info step' do
  include CacProofingHelper

  context 'successful verification' do
    before do
      sign_in_and_2fa_user
      complete_cac_proofing_steps_before_verify_step
    end

    it 'proceeds to the next page' do
      expect(page).to have_current_path(idv_cac_proofing_verify_step)
      click_continue

      expect(page).to have_current_path(idv_cac_proofing_success_step)

      expect(SpCost.count).to eq(1)
      sp_cost = SpCost.first
      expect(sp_cost.cost_type).to eq('lexis_nexis_resolution')
      expect(sp_cost.ial).to eq(2)
    end
  end

  context 'in progress' do
    before do
      sign_in_and_2fa_user
      complete_cac_proofing_steps_before_verify_step
    end

    it 'renders in progress form' do
      # the user gets shown the wait page until a result has been stored
      allow_any_instance_of(DocumentCaptureSession).to receive(:store_proofing_result).
        and_return(nil)
      click_continue

      expect(page).to have_current_path(idv_cac_proofing_verify_wait_step)
    end
  end

  context 'timed out' do
    before do
      sign_in_and_2fa_user
      complete_cac_proofing_steps_before_verify_step
    end

    it 'allows resubmitting form' do
      allow(DocumentCaptureSession).to receive(:find_by).
        and_return(nil)
      click_continue

      expect(page).to have_current_path(idv_cac_proofing_verify_step)
      allow(DocumentCaptureSession).to receive(:find_by).and_call_original
      click_continue
      expect(page).to have_current_path(idv_cac_proofing_success_step)
    end
  end
end
