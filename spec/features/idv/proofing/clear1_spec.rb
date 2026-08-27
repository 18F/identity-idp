require 'rails_helper'
require 'axe-rspec'

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
  let(:session_id) { 'fake_session_id' }
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

  shared_examples 'the verify with CLEAR option' do |path_helper|
    it 'has no accessibility violations' do
      expect(page).to have_button(t('forms.buttons.verify_with_clear1'))
      expect_page_to_have_no_accessibility_violations(page)
    end

    it 'shows the option as designed' do
      expect(page).to have_content(t('doc_auth.headings.verify_with_existing_account'))
      expect(page).to have_content(t('doc_auth.info.verify_with_clear1'))
      expect(page).to have_link(t('doc_auth.info.verify_with_clear1_link_text'))
      expect(page).to have_button(t('forms.buttons.verify_with_clear1'))
    end

    %i[es fr zh].each do |locale|
      it "shows the option translated in #{locale}" do
        click_button t('i18n.language', locale: 'en')
        click_link t("i18n.locale.#{locale}")
        expect(page).to have_current_path(send(path_helper, locale:))

        expect(page).to have_content(
          t('doc_auth.headings.verify_with_existing_account', locale:),
        )
        expect(page).to have_content(t('doc_auth.info.verify_with_clear1', locale:))
        expect(page).to have_link(t('doc_auth.info.verify_with_clear1_link_text', locale:))
        expect(page).to have_button(t('forms.buttons.verify_with_clear1', locale:))
      end
    end
  end

  context 'desktop flow', driver: :headless_chrome do
    before do
      visit_idp_from_oidc_sp_with_ial2
      sign_in_and_2fa_user(user)
      complete_doc_auth_steps_before_hybrid_handoff_step
    end

    it_behaves_like 'the verify with CLEAR option', :idv_hybrid_handoff_path

    it 'returns to hybrid handoff when the clear1 session request fails' do
      clear1_session_stub(status: 500)
      click_button t('forms.buttons.verify_with_clear1')

      expect(page).to have_current_path(idv_hybrid_handoff_path)
      expect(page).to have_button(t('forms.buttons.verify_with_clear1'))
    end

    it 'redirects user to clear app' do
      clear1_session_stub
      click_button t('forms.buttons.verify_with_clear1')

      expect(page).to have_current_path(clear_app_url)
      expect(page).not_to have_content(t('headings.redirecting'))
      expect(fake_analytics).to have_logged_event(
        'IdV: doc auth hybrid handoff submitted',
        hash_including(step: 'hybrid_handoff', destination: :clear1_session),
      )
    end
  end

  context 'mobile flow', driver: :headless_chrome_mobile do
    before do
      visit_idp_from_oidc_sp_with_ial2
      sign_in_and_2fa_user(user)
      complete_doc_auth_steps_before_hybrid_handoff_step
      expect(page).to have_current_path(idv_how_to_verify_path)
    end

    it_behaves_like 'the verify with CLEAR option', :idv_how_to_verify_path

    it 'redirects user to clear app from how to verify' do
      clear1_session_stub
      click_button t('forms.buttons.verify_with_clear1')

      expect(page).to have_current_path(clear_app_url)
      expect(page).not_to have_content(t('headings.redirecting'))
      expect(fake_analytics).to have_logged_event(
        :idv_doc_auth_how_to_verify_submitted,
        hash_including(step: 'how_to_verify', selection: 'clear1', success: true),
      )
    end

    context 'when in person proofing is not offered' do
      before do
        allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled)
          .and_return(false)
      end

      it 'offers CLEAR without the post office option and redirects to clear app' do
        page.refresh
        expect(page).to have_current_path(idv_how_to_verify_path)
        expect(page).not_to have_content(t('doc_auth.headings.verify_at_post_office'))

        clear1_session_stub
        click_button t('forms.buttons.verify_with_clear1')

        expect(page).to have_current_path(clear_app_url)
      end
    end
  end

  def clear1_session_stub(status: 200, token: 'fake_token', session_id: 'fake_session_id')
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
          id: session_id,
        }.compact.to_json,
      )
  end
end
