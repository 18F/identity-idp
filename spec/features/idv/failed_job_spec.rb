require 'rails_helper'

feature 'IdV session' do
  include IdvHelper

  context 'VendorValidatorJob raises an error', idv_job: true do
    it 'displays a warning that something went wrong' do
      sign_in_and_2fa_user

      step = instance_double(
        Idv::ProfileStep, attempts_exceeded?: false, vendor_validator_job_failed?: true
      )
      allow(Idv::ProfileStep).to receive(:new).and_return(step)
      allow(step).to receive(:submit).
        and_return(FormResponse.new(success: false, errors: {}, extra: {}))

      visit verify_session_path
      fill_out_idv_form_ok
      click_idv_continue

      expect(page).to have_current_path(verify_session_result_path)
      expect(page).to have_content t('idv.modal.sessions.jobfail')
    end
  end
end
