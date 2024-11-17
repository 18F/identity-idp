require 'rails_helper'

RSpec.feature 'document capture step', :js do
  include IdvStepHelper
  include DocAuthHelper
  include DocCaptureHelper
  include ActionView::Helpers::DateHelper

  let(:max_attempts) { 3 }
  let(:fake_analytics) { FakeAnalytics.new }
  let(:socure_webhook_secret_key) { 'socure_webhook_secret_key' }
  let(:fake_socure_endpoint) { 'https://fake-socure.test/' }
  let(:fake_socure_document_capture_app_url) { 'https://verify.socure.test/something' }
  let(:docv_transaction_token) { 'fake docv transaction token' }
  let(:fake_socure_idplus_base_url) { 'https://verification-data.fake-socure.test' }
  # let(:fake_socure_response) do
  #   {
  #     referenceId: 'socure-reference-id',
  #     data: {
  #       eventId: 'socure-event-id',
  #       docvTransactionToken: docv_transaction_token,
  #       qrCode: 'qr-code',
  #       url: fake_socure_document_capture_app_url,
  #     },
  #   }
  # end
  let(:fake_socure_status) { 200 }

  before(:each) do
    allow(IdentityConfig.store).to receive(:socure_enabled).and_return(true)
    allow(DocAuthRouter).to receive(:doc_auth_vendor_for_bucket).and_return(Idp::Constants::Vendors::SOCURE)
    allow_any_instance_of(ServiceProviderSession).to receive(:sp_name).and_return('Test SP')
    allow(IdentityConfig.store).to receive(:socure_webhook_secret_key).and_return(socure_webhook_secret_key)
    allow(IdentityConfig.store).to receive(:socure_document_request_endpoint).
      and_return(fake_socure_endpoint)
    allow(IdentityConfig.store).to receive(:ruby_workers_idv_enabled).and_return(false)
    allow(IdentityConfig.store).to receive(:socure_idplus_base_url).and_return(fake_socure_idplus_base_url)
    allow_any_instance_of(ApplicationController).to receive(:analytics).and_return(fake_analytics)
    @docv_transaction_token = SecureRandom.hex
    stub_request(:post, fake_socure_endpoint).
      to_return(
        status: fake_socure_status,
        body: {
          referenceId: 'socure-reference-id',
          data: {
            eventId: 'socure-event-id',
            docvTransactionToken: @docv_transaction_token,
            qrCode: 'qr-code',
            url: fake_socure_document_capture_app_url,
          },
        }.to_json,
      )
  end

  before(:all) do
    User.destroy_all
    @user = user_with_2fa
  end

  after(:all) { @user.destroy }

  context 'standard desktop flow' do
    before do
      visit_idp_from_oidc_sp_with_ial2
      sign_in_and_2fa_user(@user)
      complete_doc_auth_steps_before_document_capture_step
      click_idv_continue
    end

    context 'rate limits calls to backend docauth vendor', allow_browser_log: true do
      before do
        stub_verification_data
        allow(IdentityConfig.store).to receive(:doc_auth_max_attempts).and_return(max_attempts)
        (max_attempts - 1).times do
          socure_docv_send_webhook(docv_transaction_token: @docv_transaction_token)
        end
      end

      it 'redirects to the rate limited error page' do
        expect(page).to have_current_path(fake_socure_document_capture_app_url)
        visit idv_socure_document_capture_path
        expect(page).to have_current_path(idv_socure_document_capture_path)
        socure_docv_send_webhook(
          docv_transaction_token: @docv_transaction_token,
        )
        visit idv_socure_document_capture_path
        expect(page).to have_current_path(idv_session_errors_rate_limited_path)
        expect(fake_analytics).to have_logged_event(
          'Rate Limit Reached',
          limiter_type: :idv_doc_auth,
        )
      end

      context 'successfully processes image on last attempt' do
        before do
          DocAuth::Mock::DocAuthMockClient.reset!
        end

        it 'proceeds to the next page with valid info' do
          expect(page).to have_current_path(fake_socure_document_capture_app_url)
          visit idv_socure_document_capture_path
          expect(page).to have_current_path(idv_socure_document_capture_path)
          socure_docv_send_webhook(
            docv_transaction_token: @docv_transaction_token,
          )

          visit idv_socure_document_capture_update_path
          expect(page).to have_current_path(idv_ssn_url)

          visit idv_socure_document_capture_path

          expect(page).to have_current_path(idv_session_errors_rate_limited_path)
        end
      end
    end

    context 'network connection errors' do
      it 'catches network connection errors on document request', allow_browser_log: true do
        # DocAuth::Mock::DocAuthMockClient.mock_response!(
        #   method: :post_front_image,
        #   response: DocAuth::Response.new(
        #     success: false,
        #     errors: { network: I18n.t('doc_auth.errors.general.network_error') },
        #   ),
        # )

        # attach_and_submit_images

        # expect(page).to have_current_path(idv_document_capture_url)
        # expect(page).to have_content(I18n.t('doc_auth.errors.general.network_error'))
      end

      it 'catches network connection errors on verification data request', allow_browser_log: true do
      end

    end

    it 'does not track state if state tracking is disabled' do
      allow(IdentityConfig.store).to receive(:state_tracking_enabled).and_return(false)
      socure_docv_send_webhook(
        docv_transaction_token: @docv_transaction_token,
      )

      expect(DocAuthLog.find_by(user_id: @user.id).state).to be_nil
    end
  end

  context 'standard mobile flow' do
    before do
      stub_verification_data
    end
    it 'proceeds to the next page with valid info' do
      perform_in_browser(:mobile) do
        visit_idp_from_oidc_sp_with_ial2
        sign_in_and_2fa_user(@user)
        complete_doc_auth_steps_before_document_capture_step

        expect(page).to have_current_path(idv_socure_document_capture_url)
        expect_step_indicator_current_step(t('step_indicator.flows.idv.verify_id'))
        click_idv_continue
        socure_docv_send_webhook(
          docv_transaction_token: @docv_transaction_token,
        )
        visit idv_socure_document_capture_update_path
        expect(page).to have_current_path(idv_ssn_url)
        expect_costing_for_document
        expect(DocAuthLog.find_by(user_id: @user.id).state).to eq('NY')

        fill_out_ssn_form_ok
        click_idv_continue
        complete_verify_step
        expect(page).to have_current_path(idv_phone_url)
      end
    end
  end

  def expect_rate_limited_header(expected_to_be_present)
    review_issues_h1_heading = strip_tags(t('doc_auth.errors.rate_limited_heading'))
    if expected_to_be_present
      expect(page).to have_content(review_issues_h1_heading)
    else
      expect(page).not_to have_content(review_issues_h1_heading)
    end
  end

  def expect_rate_limit_warning(expected_remaining_attempts)
    review_issues_rate_limit_warning = strip_tags(
      t(
        'idv.failure.attempts_html',
        count: expected_remaining_attempts,
      ),
    )
    expect(page).to have_content(review_issues_rate_limit_warning)
  end

  # do we need this?
  def expect_resubmit_page_inline_error_messages(expected_count)
    resubmit_page_inline_error_messages = strip_tags(
      t('doc_auth.errors.general.fallback_field_level'),
    )
    expect(page).to have_content(resubmit_page_inline_error_messages).exactly(expected_count)
  end

  # do we need this?
  def expect_to_try_again
    click_try_again
    expect(page).to have_current_path(idv_socure_document_capture_path)
  end

  def expect_costing_for_document
    # %i[acuant_front_image acuant_back_image acuant_result].each do |cost_type|
    #   expect(costing_for(cost_type)).to be_present
    # end
  end

  def costing_for(cost_type)
    # SpCost.where(ial: 2, issuer: 'urn:gov:gsa:openidconnect:sp:server', cost_type: cost_type.to_s)
  end

  def stub_verification_data(decision: 'accept')
    stub_request(:post, "#{fake_socure_idplus_base_url}/api/3.0/EmailAuthScore").
      to_return(
        headers: {
          'Content-Type' => 'application/json',
        },
        body: JSON.generate(socure_response_body(decision:)),
      )
  end

  def socure_response_body(decision:)
    response = JSON.parse(
      '{
        "referenceId": "a1234b56-e789-0123-4fga-56b7c890d123",
        "previousReferenceId": "e9c170f2-b3e4-423b-a373-5d6e1e9b23f8",
        "documentVerification": {
          "reasonCodes": [
            "I831",
            "R810"
          ],
          "documentType": {
            "type": "Drivers License",
            "country": "USA",
            "state": "NY"
          },
          "decision": {
            "name": "lenient",
            "value": "review"
          },
          "documentData": {
            "firstName": "Dwayne",
            "surName": "Denver",
            "fullName": "Dwayne Denver",
            "address": "123 Example Street, New York City, NY 10001",
            "parsedAddress": {
              "physicalAddress": "123 Example Street",
              "physicalAddress2": "New York City NY 10001",
              "city": "New York City",
              "state": "NY",
              "country": "US",
              "zip": "10001"
            },
            "documentNumber": "000000000",
            "dob": "2020-01-01",
            "issueDate": "2024-01-01",
            "expirationDate": "2027-01-01"
          }
        },
        "customerProfile": {
          "customerUserId": "129",
          "userId": "u8JpWn4QsF3R7tA2"
        }
      }',
    )
    response['documentVerification']['decision']['value'] = decision
    response
  end
end

# do wee need below tests copied from non-socure document_capture
# RSpec.feature 'direct access to IPP on desktop', :js do
#   include IdvStepHelper
#   include DocAuthHelper

#   context 'before handoff page' do
#     let(:sp_ipp_enabled) { true }
#     let(:in_person_proofing_opt_in_enabled) { true }
#     let(:facial_match_required) { true }
#     let(:user) { user_with_2fa }

#     before do
#       service_provider = create(:service_provider, :active, :in_person_proofing_enabled)
#       allow(IdentityConfig.store).to receive(:doc_auth_selfie_desktop_test_mode).and_return(false)
#       allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
#       allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled).and_return(
#         in_person_proofing_opt_in_enabled,
#       )
#       allow(IdentityConfig.store).to receive(:allowed_biometric_ial_providers).
#         and_return([service_provider.issuer])
#       allow(IdentityConfig.store).to receive(
#         :allowed_valid_authn_contexts_semantic_providers,
#       ).and_return([service_provider.issuer])
#       allow_any_instance_of(ServiceProvider).to receive(:in_person_proofing_enabled).
#         and_return(false)
#       visit_idp_from_sp_with_ial2(
#         :oidc,
#         **{ client_id: service_provider.issuer,
#             facial_match_required: facial_match_required },
#       )
#       sign_in_via_branded_page(user)
#       complete_doc_auth_steps_before_agreement_step

#       visit idv_document_capture_path(step: 'hybrid_handoff')
#     end

#     context 'when selfie is enabled' do
#       it 'redirects back to agreement page' do
#         expect(page).to have_current_path(idv_agreement_path)
#       end
#     end

#     context 'when selfie is disabled' do
#       let(:facial_match_required) { false }

#       it 'redirects back to agreement page' do
#         expect(page).to have_current_path(idv_agreement_path)
#       end
#     end
#   end
# end
