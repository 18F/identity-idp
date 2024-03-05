require 'rails_helper'

RSpec.describe 'IdV step up flow', allowed_extra_analytics: [:*] do
  include IdvStepHelper
  include InPersonHelper

  let(:sp) { :oidc }
  let(:sp_name) { 'Test SP' }

  let(:user) do
    create(:user, :proofed, password: RequestHelper::VALID_PASSWORD)
  end

  before do
    allow(IdentityConfig.store).to receive(:doc_auth_selfie_capture_enabled).and_return(true)
  end

  scenario 'User with active profile can redo idv when selfie required', js: true do
    visit_idp_from_sp_with_ial2(sp, biometric_comparison_required: true)
    sign_in_live_with_2fa(user)

    expect(page).to have_current_path(idv_welcome_path)
    expect(page).to have_content('Verify your identity again and take a photo of yourself to access this service')

    complete_proofing_steps(with_selfie: true)
  end

  scenario 'User with active profile cannot redo idv when selfie not required' do
    visit_idp_from_sp_with_ial2(sp)
    sign_in_live_with_2fa(user)
    expect(page).to have_current_path(sign_up_completed_path)
  end
end
