require 'rails_helper'

feature 'doc auth link sent step' do
  include IdvStepHelper
  include DocAuthHelper
  include DocCaptureHelper

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
  end

  it 'Correctly renders the link sent step page' do
    expect(page).to have_current_path(idv_link_sent_url)
    expect_step_indicator_current_step(t('step_indicator.flows.idv.verify_id'))
    expect(page).to have_content(phone_number)

    # does not allow skipping ahead to ssn step
    visit(idv_ssn_url)
    expect(page).to have_current_path(idv_link_sent_url)
  end

  context 'when link sent polling is enabled' do
    let(:doc_capture_polling_enabled) { true }

    it 'Does not show continue button', :js do
      # Prevent errors caused by "Do you want to leave this page?" alert
      page.evaluate_script('window.onbeforeunload = null;')
      page.evaluate_script('window.onunload = null;')

      expect(page).not_to have_content(I18n.t('doc_auth.buttons.continue'))
    end
  end
end
