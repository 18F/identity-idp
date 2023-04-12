require 'rails_helper'

feature 'capture complete step', :js do
  include IdvStepHelper
  include DocAuthHelper
  include DocCaptureHelper

  let(:user) { user_with_2fa }

  before do
    allow(IdentityConfig.store).to receive(:doc_auth_hybrid_mobile_controllers_enabled).
      and_return(true)
    complete_doc_capture_steps_before_capture_complete_step(user)
    allow_any_instance_of(Browser).to receive(:mobile?).and_return(true)
    sign_in_and_2fa_user(user)
    visit(idv_hybrid_mobile_capture_complete_url)
  end

  it 'is on the correct page' do
    expect(page).to have_current_path(idv_hybrid_mobile_capture_complete_url)
    expect(page).to have_content(t('doc_auth.headings.capture_complete'))
    expect_step_indicator_current_step(t('step_indicator.flows.idv.verify_id'))
  end
end
