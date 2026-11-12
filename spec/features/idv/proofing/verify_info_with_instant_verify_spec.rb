require 'rails_helper'

RSpec.feature 'verify info with instant verify', :js, driver: :headless_chrome_mobile do
  include IdvStepHelper
  include DocAuthHelper
  include DocCaptureHelper
  include ActionView::Helpers::DateHelper

  let(:user) { user_with_2fa }
  let(:max_attempts) { 3 }
  let(:fake_analytics) { FakeAnalytics.new }
  let(:attempts_api_tracker) { AttemptsApiTrackingHelper::FakeAttemptsTracker.new }
  let(:socure_docv_webhook_secret_key) { 'socure_docv_webhook_secret_key' }
  let(:fake_socure_docv_document_request_endpoint) { 'https://fake-socure.test/document-request' }
  let(:fake_socure_document_capture_app_url) { 'https://verify.fake-socure.test/something' }
  let(:socure_docv_webhook_repeat_endpoints) { [] }
  let(:idv_socure_reason_codes_docv_mdl) { ['mdl_code1', 'mdl_code2'] }
  let(:idv_doc_auth_mdl_enabled_percent) { 0 }

  let(:resolution_response) do
    JSON.parse(LexisNexisFixtures.ddp_instant_verify_occupancy_fail_response_json)
  end

  before do
    allow(IdentityConfig.store).to receive_messages(
      doc_auth_max_attempts: max_attempts,
      doc_auth_passport_selfie_vendor_lexis_nexis_percent: 0,
      doc_auth_passport_selfie_vendor_socure_percent: 100,
      doc_auth_passport_selfie_vendor_switching_enabled: true,
      doc_auth_passport_vendor_lexis_nexis_percent: 0,
      doc_auth_passport_vendor_socure_percent: 100,
      doc_auth_passport_vendor_switching_enabled: true,
      doc_auth_selfie_vendor_lexis_nexis_percent: 0,
      doc_auth_selfie_vendor_socure_percent: 100,
      doc_auth_selfie_vendor_switching_enabled: true,
      doc_auth_vendor_lexis_nexis_percent: 0,
      doc_auth_vendor_socure_percent: 100,
      doc_auth_vendor_switching_enabled: true,
      idv_socure_reason_codes_docv_mdl:,
      ruby_workers_idv_enabled: false,
      socure_docv_document_request_endpoint: fake_socure_docv_document_request_endpoint,
      socure_docv_images_request_endpoint: 'https://fake-socure.test/docv/images/',
      socure_docv_enabled: true,
      socure_docv_webhook_repeat_endpoints:,
      socure_docv_webhook_secret_key:,
      idv_doc_auth_mdl_enabled_percent: 100,
      dos_passport_mrz_endpoint: 'https://fake-socure.test/mrz',
      lexisnexis_threatmetrix_base_url: 'https://fake-lexis-nexis.test',
      idv_resolution_vendor_instant_verify_ddp_percent: 100,
      idv_resolution_vendor_instant_verify_percent: 0,
      idv_resolution_vendor_socure_kyc_percent: 0,
      lexisnexis_threatmetrix_org_id: 'test_org_id',
      lexisnexis_instant_verify_ddp_policy: 'test-policy',
      idv_resolution_vendor_switching_enabled: true,
    )
    allow_any_instance_of(ServiceProviderSession).to receive(:sp_name).and_return('Test SP')
    socure_docv_webhook_repeat_endpoints.each { |endpoint| stub_request(:post, endpoint) }
    allow_any_instance_of(ApplicationController).to receive(:analytics).and_return(fake_analytics)
    allow_any_instance_of(ApplicationController).to receive(:attempts_api_tracker).and_return(
      attempts_api_tracker,
    )
    allow_any_instance_of(SocureDocvResultsJob).to receive(:analytics).and_return(fake_analytics)
    stub_request(:get, %r{#{IdentityConfig.store.socure_docv_images_request_endpoint}})
    @docv_transaction_token = stub_docv_document_request(user:)
    reload_ab_tests
  end

  context 'when resolution fails due to occupancy_not_verified_fail only' do
    before do
      stub_request(
        :post,
        'https://fake-lexis-nexis.test/api/attribute-query',
      ).to_return(
        body: resolution_response.to_json,
        status: 200,
      )
    end

    context 'when the document type is mDL' do
      before do
        DocAuth::Mock::DocAuthMockClient.reset!
        @docv_stub = stub_docv_verification_data_pass(
          docv_transaction_token: @docv_transaction_token,
          reason_codes: idv_socure_reason_codes_docv_mdl,
          user:,
        )
      end

      it 'allows the user to bypass resolution failures' do
        perform_in_browser(:mobile) do
          complete_verify_info_with_mdl(user, @docv_transaction_token)

          expect(fake_analytics).to have_logged_event(
            'IdV: doc auth verify proofing results',
            hash_including(
              proofing_results: hash_including(
                context: hash_including(
                  stages: hash_including(
                    resolution: hash_including(
                      result_overrides: [{
                        name: 'id_resolution_check_override',
                        overrides: [{ IdentityOccupancyVerified: 'occupancy_not_verified_fail' }],
                        reason: 'mdl',
                      }],
                    ),
                  ),
                ),
              ),
            ),
          )

          expect(page).to have_current_path(idv_phone_url)
        end
      end
    end

    context 'when the document type is drivers license' do
      before do
        DocAuth::Mock::DocAuthMockClient.reset!
        @docv_stub = stub_docv_verification_data_pass(
          docv_transaction_token: @docv_transaction_token,
          user:,
        )
      end

      it 'redirects the user to the errors page' do
        perform_in_browser(:mobile) do
          complete_verify_info_with_drivers_license(user, @docv_transaction_token)

          expect(fake_analytics).to have_logged_event(
            'IdV: doc auth verify proofing results',
            hash_including(
              proofing_results: hash_including(
                context: hash_including(
                  stages: hash_including(
                    resolution: hash_including(
                      result_overrides: [],
                    ),
                  ),
                ),
              ),
            ),
          )

          expect(page).to have_current_path(idv_session_errors_warning_path)
        end
      end
    end
  end

  context 'when resolution fails due to occupancy_not_verified_fail with additional errors' do
    let(:resolution_response) do
      super().dig(
        'integration_hub_results', 'test_org_id:test-policy', 'Execute Instant Verify',
        'tps_vendor_raw_response', 'Products', 0, 'Items'
      ) << {
        'ItemName' => 'IAmError',
        'ItemStatus' => 'fail',
        'ItemReason' => { 'Code' => 'i_am_error' },
      }

      super()
    end

    before do
      stub_request(
        :post,
        'https://fake-lexis-nexis.test/api/attribute-query',
      ).to_return(
        body: resolution_response.to_json,
        status: 200,
      )
    end

    context 'when the document type is mDL' do
      before do
        DocAuth::Mock::DocAuthMockClient.reset!
        @docv_stub = stub_docv_verification_data_pass(
          docv_transaction_token: @docv_transaction_token,
          reason_codes: idv_socure_reason_codes_docv_mdl,
          user:,
        )
      end

      it 'redirects the user to the errors page' do
        perform_in_browser(:mobile) do
          complete_verify_info_with_mdl(user, @docv_transaction_token)

          expect(fake_analytics).to have_logged_event(
            'IdV: doc auth verify proofing results',
            hash_including(
              proofing_results: hash_including(
                context: hash_including(
                  stages: hash_including(
                    resolution: hash_including(
                      result_overrides: [],
                    ),
                  ),
                ),
              ),
            ),
          )

          expect(page).to have_current_path(idv_session_errors_warning_path)
        end
      end
    end

    context 'when the document type is drivers license' do
      before do
        DocAuth::Mock::DocAuthMockClient.reset!
        @docv_stub = stub_docv_verification_data_pass(
          docv_transaction_token: @docv_transaction_token,
          user:,
        )
      end

      it 'redirects the user to the errors page' do
        perform_in_browser(:mobile) do
          complete_verify_info_with_drivers_license(user, @docv_transaction_token)

          expect(fake_analytics).to have_logged_event(
            'IdV: doc auth verify proofing results',
            hash_including(
              proofing_results: hash_including(
                context: hash_including(
                  stages: hash_including(
                    resolution: hash_including(
                      result_overrides: [],
                    ),
                  ),
                ),
              ),
            ),
          )

          expect(page).to have_current_path(idv_session_errors_warning_path)
        end
      end
    end
  end

  def complete_verify_info_with_mdl(user, docv_transaction_token)
    visit_idp_from_oidc_sp_with_basic
    sign_in_and_2fa_user(user)
    complete_doc_auth_steps_before_hybrid_handoff_step

    expect(page).to have_current_path(idv_choose_id_type_url)
    choose(t('doc_auth.forms.id_type_preference.mdl'))
    click_on t('forms.buttons.continue')

    expect(page).to have_current_path(idv_socure_document_capture_url)
    click_on t('idv.mdl.button')
    socure_docv_upload_documents(docv_transaction_token:)
    visit idv_socure_document_capture_update_path

    expect(page).to have_current_path(idv_ssn_url)
    fill_out_ssn_form_ok
    click_idv_continue
    complete_verify_step
  end

  def complete_verify_info_with_drivers_license(user, docv_transaction_token)
    visit_idp_from_oidc_sp_with_basic
    sign_in_and_2fa_user(user)
    complete_doc_auth_steps_before_hybrid_handoff_step

    expect(page).to have_current_path(idv_choose_id_type_url)
    choose(t('doc_auth.forms.id_type_preference.drivers_license'))
    click_on t('forms.buttons.continue')

    expect(page).to have_current_path(idv_socure_document_capture_url)
    socure_docv_upload_documents(docv_transaction_token:)
    visit idv_socure_document_capture_update_path

    expect(page).to have_current_path(idv_ssn_url)
    fill_out_ssn_form_ok
    click_idv_continue
    complete_verify_step
  end
end
