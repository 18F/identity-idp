require 'rails_helper'

RSpec.describe 'when Socure throws an internal error' do
  include IdvStepHelper

  let(:fake_analytics) { FakeAnalytics.new }

  let(:socure_status) { 'Error' }
  let(:reference_id) { '360ae43f-123f-47ab-8e05-6af79752e76c' }
  let(:socure_msg) { 'InternalServerException' }

  before do
    allow_any_instance_of(ApplicationController).to receive(:analytics).and_return(fake_analytics)

    allow(IdentityConfig.store).to receive(:socure_docv_enabled).and_return(true)
    allow(DocAuthRouter).to receive(:doc_auth_vendor_for_bucket)
      .and_return(Idp::Constants::Vendors::SOCURE)

    stub_docv_document_request(
      body: { status: socure_status, referenceId: reference_id, msg: socure_msg },
    )
  end

  context 'mobile flow', :js, driver: :headless_chrome_mobile do
    before do
      visit_idp_from_oidc_sp_with_ial2
      @user = sign_in_and_2fa_user
      complete_doc_auth_steps_before_hybrid_handoff_step
      click_try_again # acting as a wait for logged_event
    end

    it 'correctly logs a document capture request submitted event', js: true do
      expect(fake_analytics).to have_logged_event(
        :idv_socure_document_request_submitted,
        hash_including(socure_status:, reference_id:, socure_msg:),
      )
    end
  end

  context 'in hybrid handoff' do
    before do
      allow(Telephony).to receive(:send_doc_auth_link).and_wrap_original do |impl, config|
        @sms_link = config[:link]
        impl.call(**config)
      end
    end

    it 'correctly logs a document capture request submitted event', js: true do
      perform_in_browser(:desktop) do
        visit_idp_from_oidc_sp_with_ial2
        sign_in_and_2fa_user
        complete_doc_auth_steps_before_hybrid_handoff_step
        click_send_link
        click_idv_continue
      end

      perform_in_browser(:mobile) do
        visit @sms_link
        click_try_again # acting as a wait for logged_event
      end

      expect(fake_analytics).to have_logged_event(
        :idv_socure_document_request_submitted,
        hash_including(socure_status:, reference_id:, socure_msg:),
      )
    end
  end
end