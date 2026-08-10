require 'rails_helper'

RSpec.feature 'clear1 inherited proofing step', :js, allow_browser_log: true do
  include IdvStepHelper
  # include DocAuthHelper
  # include DocCaptureHelper
  include ActionView::Helpers::DateHelper

  let(:user) { user_with_2fa }
  let(:max_attempts) { 3 }
  let(:fake_analytics) { FakeAnalytics.new }
  let(:idv_clear1_enabled) { true }
  let(:idv_clear1_enabled_percent) { 100 }
  let(:idv_clear1_project_id) { 'fake_project_id' }
  let(:status) { 200 }
  let(:token) { 'fake_token' }
  let(:clear_app_url) do
    "#{IdentityConfig.store.idv_clear1_api_base_url}/verify?token=#{token}"
  end
  let(:clear_session_endpoint) do
    "#{IdentityConfig.store.idv_clear1_api_base_url}/v1/verification_sessions"
  end

  before do
    allow(IdentityConfig.store).to receive_messages(
      proof_address_max_attempts: max_attempts,
      idv_clear1_enabled:,
      idv_clear1_enabled_percent:,
      idv_clear1_project_id:,
    )
    allow_any_instance_of(ServiceProviderSession).to receive(:sp_name).and_return('Test SP')
    allow_any_instance_of(ApplicationController).to receive(:analytics).and_return(fake_analytics)
    reload_ab_tests
  end

  context 'desktop flow', driver: :headless_chrome do
    it 'redirects user to clear app' do
      visit_idp_from_oidc_sp_with_ial2
      sign_in_and_2fa_user(user)
      complete_doc_auth_steps_before_hybrid_handoff_step

      @stub = clear1_session_stub(status: 500)
      click_button 'Clear1'
      expect(page).to have_current_path(idv_hybrid_handoff_path)

      remove_request_stub(@stub)
      @stub = clear1_session_stub(status: 500)
      click_button 'Clear1'
      expect(page).to have_current_path(idv_hybrid_handoff_path)

      remove_request_stub(@stub)
      @stub = clear1_session_stub
      click_button 'Clear1'
      # expect(page).to have_current_path(idv_clear1_session_url)
      expect(page).to have_current_path(clear_app_url)
    end
  end

  xcontext 'mobile flow', driver: :headless_chrome_mobile do
  end

  def clear1_session_stub(status: 200, token: 'fake_token')
    uuid_pattern = /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/i
    stub_request(:post, clear_session_endpoint)
      .with(body: hash_including(
        project_id: idv_clear1_project_id,
        redirect_url: /#{idv_clear1_session_update_url}\?state=#{uuid_pattern}/,
        custom_fields: { user_uuid: user.uuid },
      ))
      .to_return(
        status:,
        body: {
          token:,
        }.compact.to_json,
      )
  end
end
