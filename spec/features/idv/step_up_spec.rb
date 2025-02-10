require 'rails_helper'

RSpec.describe 'IdV step up flow' do
  include IdvStepHelper
  include InPersonHelper

  let(:sp) { :oidc }
  let(:sp_name) { 'Test SP' }

  let(:user) do
    create(:user, :proofed, password: RequestHelper::VALID_PASSWORD)
  end

  scenario 'User with active profile can redo idv when selfie required', js: true do
    visit_idp_from_sp_with_ial2(sp, facial_match_required: true)
    sign_in_live_with_2fa(user)

    expect(page).to have_current_path(idv_welcome_path)

    stepping_up_info_message = t(
      'doc_auth.info.stepping_up_html',
      sp_name: sp.name,
      link_html: '',
    )

    expect(page).to have_content(stepping_up_info_message)

    complete_proofing_steps(with_selfie: true)
  end

  scenario 'User with active profile cannot redo idv when selfie not required' do
    visit_idp_from_sp_with_ial2(sp)
    sign_in_live_with_2fa(user)
    expect(page).to have_current_path(sign_up_completed_path)
  end
end
