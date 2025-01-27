require 'rails_helper'

RSpec.feature 'document capture step', :js do
  include IdvStepHelper
  include DocAuthHelper
  include DocCaptureHelper
  include ActionView::Helpers::DateHelper

  let(:max_attempts) { 3 }
  let(:fake_analytics) { FakeAnalytics.new }
  let(:socure_docv_webhook_secret_key) { 'socure_docv_webhook_secret_key' }
  let(:fake_socure_docv_document_request_endpoint) { 'https://fake-socure.test/document-request' }
  let(:fake_socure_document_capture_app_url) { 'https://verify.fake-socure.test/something' }
  let(:socure_docv_verification_data_test_mode) { false }
  let(:socure_docv_webhook_repeat_endpoints) { [] }
  let(:timeout_socure_route) { idv_socure_document_capture_errors_url(error_code: :timeout) }

  before(:each) do
    allow(IdentityConfig.store).to receive(:socure_docv_enabled).and_return(true)
    allow(DocAuthRouter).to receive(:doc_auth_vendor_for_bucket)
      .and_return(Idp::Constants::Vendors::SOCURE)
    allow_any_instance_of(ServiceProviderSession).to receive(:sp_name).and_return('Test SP')
    allow(IdentityConfig.store).to receive(:socure_docv_webhook_secret_key)
      .and_return(socure_docv_webhook_secret_key)
    allow(IdentityConfig.store).to receive(:socure_docv_document_request_endpoint)
      .and_return(fake_socure_docv_document_request_endpoint)
    allow(IdentityConfig.store).to receive(:socure_docv_webhook_repeat_endpoints)
      .and_return(socure_docv_webhook_repeat_endpoints)
    socure_docv_webhook_repeat_endpoints.each { |endpoint| stub_request(:post, endpoint) }
    allow(IdentityConfig.store).to receive(:ruby_workers_idv_enabled).and_return(false)
    allow_any_instance_of(ApplicationController).to receive(:analytics).and_return(fake_analytics)
    @docv_transaction_token = stub_docv_document_request
    allow(IdentityConfig.store).to receive(:socure_docv_verification_data_test_mode)
      .and_return(socure_docv_verification_data_test_mode)
    allow(IdentityConfig.store).to receive(:doc_auth_max_attempts).and_return(max_attempts)
  end

  context 'happy path', allow_browser_log: true do
    before do
      @pass_stub = stub_docv_verification_data_pass(docv_transaction_token: @docv_transaction_token)
    end

    context 'standard mobile flow' do
      let(:socure_docv_webhook_repeat_endpoints) do # repeat webhooks
        ['https://1.example.test/thepath', 'https://2.example.test/thepath']
      end

      it 'proceeds to the next page with valid info' do
        # expect(SocureDocvRepeatWebhookJob).to receive(:perform_later)
        #   .exactly(6 * socure_docv_webhook_repeat_endpoints.length).times.and_call_original

        perform_in_browser(:mobile) do
          visit_idp_from_oidc_sp_with_ial2
          @user = sign_in_and_2fa_user
          complete_doc_auth_steps_before_document_capture_step

          expect(page).to have_current_path(idv_socure_document_capture_url)
          expect_step_indicator_current_step(t('step_indicator.flows.idv.verify_id'))

          click_idv_continue
          socure_docv_upload_documents(
            docv_transaction_token: @docv_transaction_token,
          )
          visit idv_socure_document_capture_update_path
          expect(page).to have_current_path(idv_ssn_url)

          expect(DocAuthLog.find_by(user_id: @user.id).state).to eq('NY')
          expect(fake_analytics).to have_logged_event(
            :idv_socure_document_request_submitted,
          )

          click_link 'Cancel'
          click_button 'Start over'
        end

        perform_in_browser(:desktop) do
          visit idv_socure_document_capture_update_path

          # binding.pry

          # click_button 'Continue'
          # complete_agreement_step
          # click_button 'Send link' 

          # fill_out_ssn_form_ok
          # click_idv_continue
          # complete_verify_step
          # expect(page).to have_current_path(idv_phone_url)
        end
      end
    end
  end
end

