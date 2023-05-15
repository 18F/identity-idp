require 'rails_helper'

feature 'doc auth cancel link sent action' do
  include IdvStepHelper
  include DocAuthHelper

  let(:new_controller_enabled) { false }

  before do
    allow(IdentityConfig.store).to receive(:doc_auth_link_sent_controller_enabled).
      and_return(new_controller_enabled)
    sign_in_and_2fa_user
    complete_doc_auth_steps_before_link_sent_step
  end

  it 'returns to link sent step' do
    click_doc_auth_back_link

    expect(page).to have_current_path(idv_doc_auth_upload_step)
  end

  context 'new SendLink controller is enabled' do
    let(:new_controller_enabled) { true }

    it 'returns to link sent step', :js do
      expect(page).to have_current_path(idv_link_sent_path)
      click_doc_auth_back_link

      expect(page).to have_current_path(idv_doc_auth_upload_step)
    end
  end
end
