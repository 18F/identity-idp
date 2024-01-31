require 'rails_helper'

RSpec.describe 'IdV step up flow', allowed_extra_analytics: [:*] do
  include IdvStepHelper
  include InPersonHelper

  let(:sp) { :oidc }
  let(:sp_name) { 'Test SP' }

  let(:user) do
    create(:user, :proofed)
  end

  before do
    allow(IdentityConfig.store).to receive(:doc_auth_selfie_capture_enabled).and_return(true)
  end

  scenario 'User with active profile can redo idv when selfie required', js: true do
    visit_idp_from_sp_with_ial2(sp, biometric_comparison_required: true)
    sign_in_live_with_2fa(user)

    expect(page).to have_current_path(idv_welcome_path)

    complete_doc_auth_steps_before_document_capture_step

    # TODO: Refactor this
    attach_images
    attach_selfie
    submit_images

    complete_ssn_step
    complete_verify_step
    complete_phone_step(user)
    complete_enter_password_step(user)
    acknowledge_and_confirm_personal_key
  end

  scenario 'User with active profile cannot redo idv when selfie not required' do
    visit_idp_from_sp_with_ial2(sp)
    sign_in_live_with_2fa(user)
    expect(page).to have_current_path(sign_up_completed_path)
  end
end
