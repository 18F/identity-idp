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

    context 'standard desktop flow' do
      before do
        visit_idp_from_oidc_sp_with_ial2
        @user = sign_in_and_2fa_user
        complete_doc_auth_steps_before_document_capture_step
        click_idv_continue
      end

      context 'when the user times out waiting for results' do
        before do
          DocAuth::Mock::DocAuthMockClient.reset!
          allow(IdentityConfig.store)
            .to receive(:in_person_proofing_enabled).and_return(true)
          allow(IdentityConfig.store)
            .to receive(:in_person_doc_auth_button_enabled).and_return(true)
          allow(Idv::InPersonConfig).to receive(:enabled_for_issuer?).and_return(true)
          allow(IdentityConfig.store).to receive(:doc_auth_socure_wait_polling_timeout_minutes)
            .and_return(0)
        end

        it 'shows the Try Again page and allows user to start IPP', allow_browser_log: true do
          expect(page).to have_current_path(fake_socure_document_capture_app_url)
          visit idv_socure_document_capture_path
          expect(page).to have_current_path(idv_socure_document_capture_path)
          %w[
            WAITING_FOR_USER_TO_REDIRECT,
            APP_OPENED,
            DOCUMENT_FRONT_UPLOADED,
            DOCUMENT_BACK_UPLOADED,
          ].each do |event_type|
            socure_docv_send_webhook(docv_transaction_token: @docv_transaction_token, event_type:)
          end

          # Go to the wait page
          visit idv_socure_document_capture_update_path
          expect(page).to have_current_path(idv_socure_document_capture_update_path)

          # Timeout
          visit idv_socure_document_capture_update_path
          expect(page).to have_current_path(idv_socure_errors_timeout_path)
          expect(page).to have_content(I18n.t('idv.errors.try_again_later'))

          # Try in person
          click_on t('in_person_proofing.body.cta.button')
          expect(page).to have_current_path(idv_document_capture_path(step: :idv_doc_auth))
          expect(page).to have_content(t('in_person_proofing.headings.prepare'))

          # Go back
          visit idv_socure_document_capture_update_path
          expect(page).to have_current_path(idv_socure_errors_timeout_path)

          # Try Socure again
          click_on t('idv.failure.button.warning')
          expect(page).to have_current_path(idv_socure_document_capture_path)
          expect(page).to have_content(t('doc_auth.headings.verify_with_phone'))
        end
      end

      context 'rate limits calls to backend docauth vendor', allow_browser_log: true do
        let(:socure_docv_webhook_repeat_endpoints) do # repeat webhooks
          ['https://1.example.test/thepath', 'https://2.example.test/thepath']
        end

        before do
          expect(SocureDocvRepeatWebhookJob).to receive(:perform_later)
            .exactly(6 * max_attempts * socure_docv_webhook_repeat_endpoints.length)
            .times.and_call_original
          (max_attempts - 1).times do
            socure_docv_upload_documents(docv_transaction_token: @docv_transaction_token)
          end
        end

        it 'redirects to the rate limited error page' do
          # recovers when fails to repeat webhook to an endpoint
          allow_any_instance_of(DocAuth::Socure::WebhookRepeater)
            .to receive(:send_http_post_request).and_raise('doh')
          expect(page).to have_current_path(fake_socure_document_capture_app_url)
          visit idv_socure_document_capture_path
          expect(page).to have_current_path(idv_socure_document_capture_path)
          socure_docv_upload_documents(
            docv_transaction_token: @docv_transaction_token,
          )
          visit idv_socure_document_capture_path
          expect(page).to have_current_path(idv_session_errors_rate_limited_path)
          expect(fake_analytics).to have_logged_event(
            'Rate Limit Reached',
            limiter_type: :idv_doc_auth,
          )
          expect(fake_analytics).to have_logged_event(
            :idv_socure_document_request_submitted,
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
            socure_docv_upload_documents(
              docv_transaction_token: @docv_transaction_token,
            )

            visit idv_socure_document_capture_update_path
            expect(page).to have_current_path(idv_ssn_url)

            visit idv_socure_document_capture_path

            expect(page).to have_current_path(idv_session_errors_rate_limited_path)
          end
        end
      end

      context 'shows the correct attempts on error pages' do
        before do
          stub_docv_verification_data_fail_with(
            docv_transaction_token: @docv_transaction_token,
            errors: ['XXXX'],
          )
        end

        it 'remaining attempts displayed is properly decremented' do
          socure_docv_upload_documents(
            docv_transaction_token: @docv_transaction_token,
          )
          visit idv_socure_document_capture_update_path
          expect(page).to have_content(
            strip_tags(
              t(
                'doc_auth.rate_limit_warning.plural_html',
                remaining_attempts: max_attempts - 1,
              ),
            ),
          )

          visit idv_socure_document_capture_path
          socure_docv_upload_documents(
            docv_transaction_token: @docv_transaction_token,
          )
          visit idv_socure_document_capture_update_path
          expect(page).to have_content(strip_tags(t('doc_auth.rate_limit_warning.singular_html')))
        end
      end

      context 'reuses valid capture app urls when appropriate', allow_browser_log: true do
        context 'successfully erases capture app url when flow is complete' do
          before do
            expect(DocAuth::Socure::WebhookRepeater).not_to receive(:new)
          end
          it 'proceeds to the next page with valid info' do
            document_capture_session = DocumentCaptureSession.find_by(user_id: @user.id)
            expect(document_capture_session.socure_docv_capture_app_url)
              .to eq(fake_socure_document_capture_app_url)
            expect(page).to have_current_path(fake_socure_document_capture_app_url)
            visit idv_socure_document_capture_path
            expect(page).to have_current_path(idv_socure_document_capture_path)
            document_capture_session.reload
            expect(document_capture_session.socure_docv_capture_app_url)
              .to eq(fake_socure_document_capture_app_url)
            socure_docv_upload_documents(
              docv_transaction_token: @docv_transaction_token,
            )
            document_capture_session.reload
            expect(document_capture_session.socure_docv_capture_app_url).to be_nil
          end

          it 'reuse capture app url when appropriate and creates new when not' do
            document_capture_session = DocumentCaptureSession.find_by(user_id: @user.id)
            expect(document_capture_session.socure_docv_capture_app_url)
              .to eq(fake_socure_document_capture_app_url)
            expect(page).to have_current_path(fake_socure_document_capture_app_url)
            visit idv_socure_document_capture_path
            expect(page).to have_current_path(idv_socure_document_capture_path)
            document_capture_session.reload
            expect(document_capture_session.socure_docv_capture_app_url)
              .to eq(fake_socure_document_capture_app_url)
            fake_capture_app2 = 'https://verify.fake-socure.test/capture2'
            document_capture_session.socure_docv_capture_app_url = fake_capture_app2
            document_capture_session.save
            socure_docv_send_webhook(
              docv_transaction_token: @docv_transaction_token,
              event_type: 'DOCUMENT_FRONT_UPLOADED',
            )
            document_capture_session.reload
            expect(document_capture_session.socure_docv_capture_app_url)
              .to eq(fake_capture_app2)
            socure_docv_send_webhook(
              docv_transaction_token: @docv_transaction_token,
              event_type: 'SESSION_EXPIRED',
            )
            document_capture_session.reload
            expect(document_capture_session.socure_docv_capture_app_url).to be_nil
            visit idv_socure_document_capture_path
            expect(page).to have_current_path(idv_socure_document_capture_path)
            document_capture_session.reload
            expect(document_capture_session.socure_docv_capture_app_url)
              .to eq(fake_socure_document_capture_app_url)
          end
        end
      end

      context 'network connection errors' do
        context 'getting the capture path' do
          before do
            allow_any_instance_of(Faraday::Connection).to receive(:post)
              .and_raise(Faraday::ConnectionFailed)
          end

          it 'shows the network error page', js: true do
            visit_idp_from_oidc_sp_with_ial2
            sign_in_and_2fa_user(@user)

            complete_doc_auth_steps_before_document_capture_step

            expect(page).to have_content(t('doc_auth.headers.general.network_error'))
            expect(page).to have_content(t('doc_auth.errors.general.new_network_error'))
            expect(fake_analytics).to have_logged_event(
              :idv_socure_document_request_submitted,
            )
          end
        end

        # ToDo post LG-14010. Does this belong here, or on the polling page tests?
        xit 'catches network connection errors on verification data request',
            allow_browser_log: true do
          # expect(page).to have_content(I18n.t('doc_auth.errors.general.network_error'))
        end
      end

      context 'invalid request', allow_browser_log: true do
        context 'getting the capture path w wrong api key' do
          before do
            DocAuth::Mock::DocAuthMockClient.reset!
            stub_docv_document_request(status: 401)
          end

          it 'correctly logs event', js: true do
            visit idv_socure_document_capture_path
            expect(fake_analytics).to have_logged_event(
              :idv_socure_document_request_submitted,
            )
          end
        end
      end

      it 'does not track state if state tracking is disabled' do
        allow(IdentityConfig.store).to receive(:state_tracking_enabled).and_return(false)
        socure_docv_upload_documents(
          docv_transaction_token: @docv_transaction_token,
        )

        visit idv_socure_document_capture_update_path
        expect(DocAuthLog.find_by(user_id: @user.id).state).to be_nil
      end

      it 'does track state if state tracking is enabled' do
        allow(IdentityConfig.store).to receive(:state_tracking_enabled).and_return(true)
        socure_docv_upload_documents(
          docv_transaction_token: @docv_transaction_token,
        )

        visit idv_socure_document_capture_update_path
        expect(DocAuthLog.find_by(user_id: @user.id).state).not_to be_nil
      end

      context 'when socure_docv_verification_data_test_mode is enabled' do
        let(:test_token) { 'valid-test-token' }
        let(:socure_docv_verification_data_test_mode) { true }
        before do
          allow(IdentityConfig.store).to receive(:socure_docv_verification_data_test_mode_tokens)
            .and_return([test_token])
          DocAuth::Mock::DocAuthMockClient.reset!
        end

        context 'when a valid test token is used' do
          it 'fetches verificationdata using override docvToken in request',
             allow_browser_log: true do
            remove_request_stub(@pass_stub)
            stub_docv_verification_data_pass(docv_transaction_token: test_token)

            visit idv_socure_document_capture_update_path(docv_token: test_token)
            expect(page).to have_current_path(idv_ssn_url)

            expect(DocAuthLog.find_by(user_id: @user.id).state).to eq('NY')

            fill_out_ssn_form_ok
            click_idv_continue
            complete_verify_step
            expect(page).to have_current_path(idv_phone_url)
          end
        end

        context 'when an invalid test token is used' do
          let(:invalid_token) { 'invalid-token' }
          it 'waits to fetch verificationdata using docv capture session token' do
            visit idv_socure_document_capture_update_path(docv_token: invalid_token)

            expect(page).to have_current_path(
              idv_socure_document_capture_update_path(docv_token: invalid_token),
            )
            socure_docv_upload_documents(
              docv_transaction_token: @docv_transaction_token,
            )
            visit idv_socure_document_capture_update_path(docv_token: invalid_token)

            expect(page).to have_current_path(idv_ssn_url)

            expect(DocAuthLog.find_by(user_id: @user.id).state).to eq('NY')

            fill_out_ssn_form_ok
            click_idv_continue
            complete_verify_step
            expect(page).to have_current_path(idv_phone_url)
          end
        end
      end
    end

    context 'standard mobile flow' do
      let(:socure_docv_webhook_repeat_endpoints) do # repeat webhooks
        ['https://1.example.test/thepath', 'https://2.example.test/thepath']
      end

      it 'proceeds to the next page with valid info' do
        expect(SocureDocvRepeatWebhookJob).to receive(:perform_later)
          .exactly(6 * socure_docv_webhook_repeat_endpoints.length).times.and_call_original

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

          fill_out_ssn_form_ok
          click_idv_continue
          complete_verify_step
          expect(page).to have_current_path(idv_phone_url)
        end
      end
    end
  end

  shared_examples 'a properly categorized Socure error' do |socure_error_code, expected_header_key|
    before do
      stub_docv_verification_data_fail_with(
        docv_transaction_token: @docv_transaction_token,
        errors: [socure_error_code],
      )

      visit_idp_from_oidc_sp_with_ial2
      @user = sign_in_and_2fa_user

      complete_doc_auth_steps_before_document_capture_step
      click_idv_continue
      socure_docv_upload_documents(
        docv_transaction_token: @docv_transaction_token,
      )
      visit idv_socure_document_capture_update_path
    end

    it 'shows the correct error page' do
      expect(page).to have_content(t(expected_header_key))
      expect(fake_analytics).to have_logged_event(
        :idv_socure_document_request_submitted,
      )
    end
  end

  context 'a type 1 error (because we do not recognize the code)' do
    it_behaves_like 'a properly categorized Socure error', 'XXXX', 'doc_auth.headers.unreadable_id'
  end

  context 'a type 1 error' do
    it_behaves_like 'a properly categorized Socure error', 'I848', 'doc_auth.headers.unreadable_id'
  end

  context 'a type 2 error' do
    it_behaves_like 'a properly categorized Socure error',
                    'I849',
                    'doc_auth.headers.unaccepted_id_type'
  end

  context 'a type 3 error' do
    it_behaves_like 'a properly categorized Socure error', 'R827', 'doc_auth.headers.expired_id'
  end

  context 'a type 4 error' do
    it_behaves_like 'a properly categorized Socure error', 'I808', 'doc_auth.headers.low_resolution'
  end

  context 'a type 5 error' do
    it_behaves_like 'a properly categorized Socure error', 'R845', 'doc_auth.headers.underage'
  end

  context 'a type 6 error' do
    it_behaves_like 'a properly categorized Socure error', 'I856', 'doc_auth.headers.id_not_found'
  end

  def expect_rate_limited_header(expected_to_be_present)
    review_issues_h1_heading = strip_tags(t('doc_auth.errors.rate_limited_heading'))
    if expected_to_be_present
      expect(page).to have_content(review_issues_h1_heading)
    else
      expect(page).not_to have_content(review_issues_h1_heading)
    end
  end
end

RSpec.feature 'direct access to IPP on desktop', :js do
  include IdvStepHelper
  include DocAuthHelper

  context 'before handoff page' do
    let(:sp_ipp_enabled) { true }
    let(:in_person_proofing_opt_in_enabled) { true }
    let(:facial_match_required) { false }
    let(:user) { user_with_2fa }

    before do
      service_provider = create(:service_provider, :active, :in_person_proofing_enabled)
      allow(IdentityConfig.store).to receive(:doc_auth_selfie_desktop_test_mode).and_return(false)
      allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
      allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled).and_return(
        in_person_proofing_opt_in_enabled,
      )
      allow(IdentityConfig.store).to receive(:allowed_biometric_ial_providers)
        .and_return([service_provider.issuer])
      allow(IdentityConfig.store).to receive(
        :allowed_valid_authn_contexts_semantic_providers,
      ).and_return([service_provider.issuer])
      allow_any_instance_of(ServiceProvider).to receive(:in_person_proofing_enabled)
        .and_return(false)
      allow(IdentityConfig.store).to receive(:socure_docv_enabled).and_return(true)
      allow(DocAuthRouter).to receive(:doc_auth_vendor_for_bucket)
        .and_return(Idp::Constants::Vendors::SOCURE)
      visit_idp_from_sp_with_ial2(
        :oidc,
        **{ client_id: service_provider.issuer,
            facial_match_required: facial_match_required },
      )
      sign_in_via_branded_page(user)
      complete_doc_auth_steps_before_agreement_step

      visit idv_socure_document_capture_path(step: 'hybrid_handoff')
    end

    context 'when selfie is enabled' do
      it 'redirects back to agreement page' do
        expect(page).to have_current_path(idv_agreement_path)
      end
    end

    context 'when selfie is disabled' do
      let(:facial_match_required) { false }

      it 'redirects back to agreement page' do
        expect(page).to have_current_path(idv_agreement_path)
      end
    end
  end
end
