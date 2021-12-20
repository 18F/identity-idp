require 'rails_helper'

RSpec.describe 'proofing components' do
  include DocAuthHelper
  include IdvHelper
  include SamlAuthHelper

  let(:email) { 'test@test.com' }
  let(:user) { User.find_with_email(email) }

  before do
    allow(IdentityConfig.store).to receive(:ruby_workers_idv_enabled).
      and_return(ruby_workers_idv_enabled)
    allow(IdentityConfig.store).to receive(:doc_auth_enable_presigned_s3_urls).
      and_return(doc_auth_enable_presigned_s3_urls)

    visit_idp_from_sp_with_ial2(:oidc)
    register_user(email)

    expect(current_path).to eq idv_doc_auth_step_path(step: :welcome)

    complete_all_doc_auth_steps
    click_continue
    expect(page).to have_current_path('/verify/review', wait: 5)
    fill_in 'Password', with: Features::SessionHelper::VALID_PASSWORD
    click_continue
    click_acknowledge_personal_key
  end

  context 'async proofing', js: true do
    let(:ruby_workers_idv_enabled) { true }
    let(:doc_auth_enable_presigned_s3_urls) { true }

    it 'records proofing components' do
      proofing_components = user.active_profile.proofing_components
      expect(proofing_components['document_check']).to eq('mock')
      expect(proofing_components['document_type']).to eq('state_id')
    end
  end

  context 'sync proofing', js: true do
    let(:ruby_workers_idv_enabled) { false }
    let(:doc_auth_enable_presigned_s3_urls) { false }

    it 'records proofing components' do
      proofing_components = user.active_profile.proofing_components
      expect(proofing_components['document_check']).to eq('mock')
      expect(proofing_components['document_type']).to eq('state_id')
    end
  end
end
