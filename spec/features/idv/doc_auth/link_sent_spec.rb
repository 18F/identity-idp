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
      allow(IdentityConfig.store).
        to(receive(:doc_auth_link_sent_controller_enabled).and_return(true))

      user
      complete_doc_auth_steps_before_upload_step
      clear_and_fill_in(:doc_auth_phone, phone_number)
      click_send_link
      visit(idv_link_sent_url)
    end

    it 'Correctly renders the link sent step page' do
      expect(page).to have_current_path(idv_link_sent_url)
      expect_step_indicator_current_step(t('step_indicator.flows.idv.verify_id'))
      expect(page).to have_content(phone_number)
    end

    context 'when link sent polling is enabled' do
      let(:doc_capture_polling_enabled) { true }

      # Currently get a javascript error when explicitly visiting the new url
      # Try this again once upload redirects here.
      xit 'Does not show continue button' do
        expect(page).not_to have_content('Continue') # doc_auth.buttons.continue
      end
    end
  end
end
