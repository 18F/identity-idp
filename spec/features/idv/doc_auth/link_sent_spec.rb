require 'rails_helper'

feature 'doc auth link sent step' do
  include IdvStepHelper
  include DocAuthHelper
  include DocCaptureHelper

  context 'with combined upload step enabled', js: true do
    let(:user) { sign_in_and_2fa_user }
    let(:doc_capture_polling_enabled) { false }
    let(:phone_number) { '415-555-0199' }

    before do
      allow(FeatureManagement).
        to(receive(:doc_capture_polling_enabled?).and_return(doc_capture_polling_enabled))
      user
      complete_doc_auth_steps_before_upload_step
      fill_in :doc_auth_phone, with: ''
      fill_in :doc_auth_phone, with: phone_number
      click_send_link
    end

    it 'Correctly renders the link sent step page' do
      expect(page).to have_current_path(idv_doc_auth_link_sent_step)
      expect(page).to have_content(phone_number)
    end
  end
end
