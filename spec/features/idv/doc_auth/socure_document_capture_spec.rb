require 'rails_helper'

RSpec.feature 'document capture step', :js, driver: :headless_chrome_mobile do
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
  let(:timeout_socure_route) { idv_socure_document_capture_errors_url(error_code: :timeout) }

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
      ruby_workers_idv_enabled: false,
      socure_docv_document_request_endpoint: fake_socure_docv_document_request_endpoint,
      socure_docv_enabled: true,
      socure_docv_webhook_repeat_endpoints:,
      socure_docv_webhook_secret_key:,
    )
    allow_any_instance_of(ServiceProviderSession).to receive(:sp_name).and_return('Test SP')
    socure_docv_webhook_repeat_endpoints.each { |endpoint| stub_request(:post, endpoint) }
    allow_any_instance_of(ApplicationController).to receive(:analytics).and_return(fake_analytics)
    allow_any_instance_of(ApplicationController).to receive(:attempts_api_tracker).and_return(
      attempts_api_tracker,
    )
    allow_any_instance_of(SocureDocvResultsJob).to receive(:analytics).and_return(fake_analytics)
    @docv_transaction_token = stub_docv_document_request(user:)
    reload_ab_tests
  end

  context 'happy path', allow_browser_log: true do
    before do
      @docv_stub = stub_docv_verification_data_pass(
        docv_transaction_token: @docv_transaction_token,
        user:,
      )
    end

    context 'standard desktop flow' do
      before do
        visit_idp_from_oidc_sp_with_ial2
        sign_in_and_2fa_user(user)
        complete_doc_auth_steps_before_hybrid_handoff_step
        complete_choose_id_type_step
        click_idv_continue
      end

      context 'when the user times out waiting for results' do
        before do
          DocAuth::Mock::DocAuthMockClient.reset!
          allow(IdentityConfig.store).to receive_messages(
            doc_auth_socure_wait_polling_timeout_minutes: 0,
            in_person_proofing_enabled: true,
          )
          allow(Idv::InPersonConfig).to receive(:enabled_for_issuer?).and_return(true)
          allow_any_instance_of(DocumentCaptureSession).to receive(:load_result).and_return(nil)
        end

        it 'shows the Try Again page and allows user to start IPP', allow_browser_log: true do
          expect(fake_analytics).to_not have_logged_event(
            'IdV: doc auth document_capture visited',
            hash_including(
              step: 'document_capture',
            ),
          )
          expect(fake_analytics).to have_logged_event(
            'IdV: doc auth document_capture visited',
            hash_including(
              step: 'socure_document_capture',
            ),
          )
          expect(page).to have_current_path(fake_socure_document_capture_app_url)
          visit idv_socure_document_capture_path
          expect(page).to have_current_path(idv_socure_document_capture_path)
          socure_docv_upload_documents(
            docv_transaction_token: @docv_transaction_token,
            webhooks: %w[
              WAITING_FOR_USER_TO_REDIRECT,
              APP_OPENED,
              DOCUMENT_FRONT_UPLOADED,
              DOCUMENT_BACK_UPLOADED,
            ],
          )

          # Go to the wait page
          visit idv_socure_document_capture_update_path
          expect(page).to have_current_path(idv_socure_document_capture_update_path)

          # Timeout
          visit idv_socure_document_capture_update_path
          expect(page).to have_current_path(timeout_socure_route)
          expect(page).to have_content(I18n.t('idv.errors.try_again_later'))

          # Try in person
          click_on t('in_person_proofing.body.cta.button')
          expect(page).to have_current_path(idv_document_capture_path(step: :idv_doc_auth))
          expect(page).to have_content(t('in_person_proofing.headings.prepare'))

          # Go back
          click_on t('forms.buttons.back')
          expect(page).to have_current_path(timeout_socure_route)

          # Try Socure again
          click_on t('idv.failure.button.warning')
          expect(page).to have_current_path(idv_socure_document_capture_path)
          expect(page).to have_content(t('doc_auth.headings.document_capture'))

          # Go to the wait page
          visit idv_socure_document_capture_update_path
          expect(page).to have_current_path(idv_socure_document_capture_update_path)

          # Correct intertitial with passport content
          visit idv_socure_document_capture_update_path
          document_capture_session = DocumentCaptureSession.find_by(user_id: user.id)
          document_capture_session.update(passport_status: 'requested')
          document_capture_session.save!
          click_on t('idv.failure.button.warning')
          expect(page).to have_current_path(idv_socure_document_capture_path)
          expect(page).to have_content(t('doc_auth.headings.passport_capture'))
          expect(page).to have_content(t('doc_auth.info.socure_passport', app_name: APP_NAME))
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

        context 'when we fail on the last attempt' do
          before do
            allow_any_instance_of(DocAuth::Socure::WebhookRepeater)
              .to receive(:send_http_post_request).and_raise('doh')
          end

          it 'redirects to the rate limited error page' do
            expect(attempts_api_tracker).to receive(:idv_rate_limited).with(
              limiter_type: :idv_doc_auth,
            )

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
            expect(fake_analytics).to have_logged_event(
              :idv_socure_verification_data_requested,
            )
          end
        end
      end

      context 'shows the correct attempts on error pages' do
        before do
          stub_docv_verification_data_fail_with(
            docv_transaction_token: @docv_transaction_token,
            reason_codes: ['XXXX'],
            user:,
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
                'doc_auth.rate_limit_warning_html',
                count: max_attempts - 1,
              ),
            ),
          )

          visit idv_socure_document_capture_path
          socure_docv_upload_documents(
            docv_transaction_token: @docv_transaction_token,
          )
          visit idv_socure_document_capture_update_path
          expect(page).to have_content(strip_tags(t('doc_auth.rate_limit_warning_html.one')))
        end
      end

      context 'reuses valid capture app urls when appropriate', allow_browser_log: true do
        context 'successfully erases capture app url when flow is complete' do
          before do
            expect(DocAuth::Socure::WebhookRepeater).not_to receive(:new)
          end
          it 'proceeds to the next page with valid info' do
            document_capture_session = DocumentCaptureSession.find_by(user_id: user.id)
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
            document_capture_session = DocumentCaptureSession.find_by(user_id: user.id)
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
            sign_in_and_2fa_user(user)

            complete_doc_auth_steps_before_hybrid_handoff_step
            complete_choose_id_type_step
            expect(page).to have_content(t('doc_auth.headers.general.network_error'))
            expect(page).to have_content(t('doc_auth.errors.general.new_network_error'))
            expect(fake_analytics).to have_logged_event(
              :idv_socure_document_request_submitted,
            )
            expect(fake_analytics).not_to have_logged_event(
              'IdV: doc auth image upload vendor pii validation',
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
            stub_docv_document_request(user:, status: 401)
          end

          it 'correctly logs event', js: true do
            visit idv_socure_document_capture_path
            expect(fake_analytics).to have_logged_event(
              :idv_socure_document_request_submitted,
            )
            expect(fake_analytics).not_to have_logged_event(
              'IdV: doc auth image upload vendor pii validation',
            )
          end
        end
      end

      it 'does not track state if state tracking is disabled' do
        allow(IdentityConfig.store).to receive(:state_tracking_enabled).and_return(false)
        socure_docv_upload_documents(
          docv_transaction_token: @docv_transaction_token,
        )

        # Confirm that we end up on the Socure page even if we try to
        # go to the LN / Mock one.
        visit idv_document_capture_url
        expect(page).to have_current_path(idv_socure_document_capture_url)

        visit idv_socure_document_capture_update_path
        expect(DocAuthLog.find_by(user_id: user.id).state).to be_nil
      end

      it 'does track state if state tracking is enabled' do
        allow(IdentityConfig.store).to receive(:state_tracking_enabled).and_return(true)
        socure_docv_upload_documents(
          docv_transaction_token: @docv_transaction_token,
        )

        visit idv_socure_document_capture_update_path
        expect(DocAuthLog.find_by(user_id: user.id).state).not_to be_nil
      end

      context 'not accepted id type' do
        it 'displays unaccepdted id type error message' do
          body = JSON.parse(SocureDocvFixtures.pass_json)
          body['documentVerification']['documentType']['type'] = 'Non-Document-Type'

          remove_request_stub(@docv_stub)
          stub_docv_verification_data(
            docv_transaction_token: @docv_transaction_token,
            body: body.to_json,
            user:,
          )

          socure_docv_upload_documents(
            docv_transaction_token: @docv_transaction_token,
          )
          visit idv_socure_document_capture_update_path

          expect(page).to have_content(t('doc_auth.headers.unaccepted_id_type'))
          expect(page).to have_content(t('doc_auth.errors.unaccepted_id_type'))
        end
      end
    end

    context 'webhook repearter repeats all webhooks' do
      let(:socure_docv_webhook_repeat_endpoints) do # repeat webhooks
        ['https://1.example.test/thepath', 'https://2.example.test/thepath']
      end

      it 'proceeds to the next page with valid info' do
        expect(SocureDocvRepeatWebhookJob).to receive(:perform_later)
          .exactly(6 * socure_docv_webhook_repeat_endpoints.length).times.and_call_original

        perform_in_browser(:mobile) do
          visit_idp_from_oidc_sp_with_ial2
          sign_in_and_2fa_user(user)
          complete_doc_auth_steps_before_hybrid_handoff_step
          complete_choose_id_type_step
          expect(page).to have_current_path(idv_socure_document_capture_url)
          expect_step_indicator_current_step(t('step_indicator.flows.idv.verify_id'))
          click_idv_continue
          socure_docv_upload_documents(
            docv_transaction_token: @docv_transaction_token,
          )
          visit idv_socure_document_capture_update_path
          expect(page).to have_current_path(idv_ssn_url)

          expect(DocAuthLog.find_by(user_id: user.id).state).to eq('NY')
          expect(fake_analytics).to have_logged_event(
            :idv_socure_document_request_submitted,
          )
          expect(fake_analytics).to have_logged_event(
            :idv_socure_verification_data_requested,
          )
          expect(fake_analytics).to have_logged_event(
            'IdV: doc auth image upload vendor pii validation',
          )

          fill_out_ssn_form_ok
          click_idv_continue
          complete_verify_step
          expect(page).to have_current_path(idv_phone_url)
        end
      end

      context 'when a passport is submitted' do
        before do
          allow(IdentityConfig.store).to receive_messages(
            doc_auth_passports_enabled: true,
            doc_auth_passports_percent: 100,
          )
          stub_request(:get, IdentityConfig.store.dos_passport_composite_healthcheck_endpoint)
            .to_return_json({ status: 200, body: { status: 'UP' } })
          DocAuth::Mock::DocAuthMockClient.reset!
          @docv_stub = stub_docv_verification_data_pass(
            docv_transaction_token: @docv_transaction_token,
            reason_codes: ['not_processed'],
            document_type: :passport,
            user:,
          )
          allow(IdentityConfig.store).to receive(:dos_passport_mrz_endpoint)
            .and_return('https://fake-socure.test/mrz')
        end

        it 'proceeds to the next page with valid info' do
          perform_in_browser(:mobile) do
            visit_idp_from_oidc_sp_with_ial2
            sign_in_and_2fa_user(user)

            complete_doc_auth_steps_before_hybrid_handoff_step
            click_continue
            expect(page).to have_current_path(idv_choose_id_type_url)
            choose(t('doc_auth.forms.id_type_preference.passport'))
            click_on t('forms.buttons.continue')

            expect(page).to have_current_path(idv_socure_document_capture_url)
            expect_step_indicator_current_step(t('step_indicator.flows.idv.verify_id'))

            @mrz_stub = stub_request(:post, IdentityConfig.store.dos_passport_mrz_endpoint)
              .to_return_json({ status: 200, body: { response: 'NO' } })
            click_idv_continue
            socure_docv_upload_documents(
              docv_transaction_token: @docv_transaction_token,
            )
            visit idv_socure_document_capture_update_path

            expect(page).to have_current_path(idv_socure_document_capture_errors_url)
            expect(page).to have_content(t('idv.errors.try_again_later'))

            click_on t('idv.failure.button.warning')

            remove_request_stub(@mrz_stub)

            expect(page).to have_current_path(idv_socure_document_capture_url)
            expect_step_indicator_current_step(t('step_indicator.flows.idv.verify_id'))

            stub_request(:post, IdentityConfig.store.dos_passport_mrz_endpoint)
              .to_return_json({ status: 200, body: { response: 'YES' } })
            click_idv_continue
            socure_docv_upload_documents(
              docv_transaction_token: @docv_transaction_token,
            )
            visit idv_socure_document_capture_update_path

            expect(page).to have_current_path(idv_ssn_url)

            expect(fake_analytics).to have_logged_event(
              :idv_socure_document_request_submitted,
            )
            expect(fake_analytics).to have_logged_event(
              :idv_socure_verification_data_requested,
            )
            expect(fake_analytics).to have_logged_event(
              'IdV: doc auth image upload vendor pii validation',
            )

            fill_out_ssn_form_ok
            click_idv_continue
          end
        end

        context 'when a selfie is required' do
          let(:socure_docv_webhook_repeat_endpoints) { [] }
          let(:max_attempts) { 4 }

          before do
            allow(IdentityConfig.store).to receive_messages(
              doc_auth_socure_wait_polling_timeout_minutes: 0,
              idv_socure_reason_codes_docv_selfie_fail: ['fail'],
              idv_socure_reason_codes_docv_selfie_not_processed: ['not_processed'],
              idv_socure_reason_codes_docv_selfie_pass: ['pass'],
              use_vot_in_sp_requests: true,
            )
            visit_idp_from_oidc_sp_with_ial2(facial_match_required: true)
            stub_request(:post, IdentityConfig.store.dos_passport_mrz_endpoint)
              .to_return_json({ status: 200, body: { response: 'YES' } })
          end

          it 'proceeds to the next page with valid info' do
            visit_idp_from_oidc_sp_with_ial2(facial_match_required: true)
            sign_in_and_2fa_user(user)

            complete_doc_auth_steps_before_hybrid_handoff_step
            click_continue
            expect(page).to have_current_path(idv_choose_id_type_url)
            choose(t('doc_auth.forms.id_type_preference.passport'))
            click_on t('forms.buttons.continue')

            expect(page).to have_current_path(idv_socure_document_capture_url)
            expect_step_indicator_current_step(t('step_indicator.flows.idv.verify_id'))
            click_idv_continue
            socure_docv_upload_documents(
              docv_transaction_token: @docv_transaction_token,
            )

            visit idv_socure_document_capture_update_path
            expect(page).to have_current_path(idv_socure_document_capture_errors_url)
            expect(page).to have_content(t('idv.errors.try_again_later'))

            click_on t('idv.failure.button.warning')

            remove_request_stub(@docv_stub)
            @docv_stub = stub_docv_verification_data_pass(
              docv_transaction_token: @docv_transaction_token,
              reason_codes: ['fail'],
              user:,
              document_type: :passport,
            )

            click_idv_continue
            socure_docv_upload_documents(
              docv_transaction_token: @docv_transaction_token,
              webhooks: selfie_webhook_list,
            )

            visit idv_socure_document_capture_update_path
            expect(page).to have_current_path(idv_socure_document_capture_errors_url)

            expect(page).to have_content(t('doc_auth.errors.selfie_fail_heading'))

            click_on t('idv.failure.button.warning')

            remove_request_stub(@docv_stub)
            @docv_stub = stub_docv_verification_data_fail_with(
              docv_transaction_token: @docv_transaction_token,
              reason_codes: ['pass'],
              user:,
              document_type: :passport,
            )

            click_idv_continue
            socure_docv_upload_documents(
              docv_transaction_token: @docv_transaction_token,
              webhooks: selfie_webhook_list,
            )

            visit idv_socure_document_capture_update_path
            expect(page).to have_current_path(idv_socure_document_capture_errors_url)
            expect(page).to have_content(t('doc_auth.headers.unreadable_id'))

            click_on t('idv.failure.button.warning')

            remove_request_stub(@docv_stub)
            @docv_stub = stub_docv_verification_data_pass(
              docv_transaction_token: @docv_transaction_token,
              reason_codes: ['pass'],
              user:,
              document_type: :passport,
            )

            click_idv_continue
            socure_docv_upload_documents(
              docv_transaction_token: @docv_transaction_token,
              webhooks: selfie_webhook_list,
            )

            visit idv_socure_document_capture_update_path

            expect(page).to have_current_path(idv_ssn_url)

            expect(fake_analytics).to have_logged_event(
              :idv_socure_document_request_submitted,
            )
            expect(fake_analytics).to have_logged_event(
              :idv_socure_verification_data_requested,
            )
            expect(fake_analytics).to have_logged_event(
              'IdV: doc auth image upload vendor pii validation',
            )

            fill_out_ssn_form_ok
            click_idv_continue
          end
        end
      end
    end

    context 'selfie required' do
      let(:max_attempts) { 5 }
      before do
        allow(IdentityConfig.store).to receive_messages(
          doc_auth_socure_wait_polling_timeout_minutes: 0,
          idv_socure_reason_codes_docv_selfie_fail: ['fail'],
          idv_socure_reason_codes_docv_selfie_not_processed: ['not_processed'],
          idv_socure_reason_codes_docv_selfie_pass: ['pass'],
          use_vot_in_sp_requests: true,
        )
        visit_idp_from_oidc_sp_with_ial2(facial_match_required: true)
        sign_in_and_2fa_user(user)
        complete_doc_auth_steps_before_hybrid_handoff_step
        complete_choose_id_type_step
      end

      it 'proceeds to the next page with valid info' do
        expect(page).to have_current_path(idv_socure_document_capture_url)
        expect_step_indicator_current_step(t('step_indicator.flows.idv.verify_id'))
        click_idv_continue
        socure_docv_upload_documents(
          docv_transaction_token: @docv_transaction_token,
        )

        visit idv_socure_document_capture_update_path
        expect(page).to have_current_path(idv_socure_document_capture_errors_url)
        expect(page).to have_content(t('idv.errors.try_again_later'))

        click_on t('idv.failure.button.warning')

        remove_request_stub(@docv_stub)
        @docv_stub = stub_docv_verification_data_pass(
          docv_transaction_token: @docv_transaction_token,
          reason_codes: ['not_processed'],
          user:,
        )

        click_idv_continue
        socure_docv_upload_documents(
          docv_transaction_token: @docv_transaction_token,
          webhooks: selfie_webhook_list,
        )

        visit idv_socure_document_capture_update_path
        expect(page).to have_current_path(idv_socure_document_capture_errors_url)
        expect(page).to have_content(t('idv.errors.try_again_later'))

        click_on t('idv.failure.button.warning')

        remove_request_stub(@docv_stub)
        @docv_stub = stub_docv_verification_data_fail_with(
          docv_transaction_token: @docv_transaction_token,
          reason_codes: ['pass'],
          user:,
        )

        click_idv_continue
        socure_docv_upload_documents(
          docv_transaction_token: @docv_transaction_token,
          webhooks: selfie_webhook_list,
        )

        visit idv_socure_document_capture_update_path
        expect(page).to have_current_path(idv_socure_document_capture_errors_url)
        expect(page).to have_content(t('doc_auth.headers.unreadable_id'))

        click_on t('idv.failure.button.warning')

        remove_request_stub(@docv_stub)
        @docv_stub = stub_docv_verification_data_pass(
          docv_transaction_token: @docv_transaction_token,
          reason_codes: ['pass'],
          user:,
        )

        click_idv_continue
        socure_docv_upload_documents(
          docv_transaction_token: @docv_transaction_token,
          webhooks: selfie_webhook_list,
        )

        visit idv_socure_document_capture_update_path

        expect(page).to have_current_path(idv_ssn_url)

        expect(fake_analytics).to have_logged_event(
          :idv_socure_document_request_submitted,
        )
        expect(fake_analytics).to have_logged_event(
          :idv_socure_verification_data_requested,
        )
        expect(fake_analytics).to have_logged_event(
          'IdV: doc auth image upload vendor pii validation',
        )

        fill_out_ssn_form_ok
        click_idv_continue
        complete_verify_step
        expect(page).to have_current_path(idv_phone_url)
      end
    end
  end

  shared_examples 'a properly categorized Socure error' do |socure_error_code, expected_header_key|
    before do
      stub_docv_verification_data_fail_with(
        docv_transaction_token: @docv_transaction_token,
        reason_codes: [socure_error_code],
        user:,
      )

      visit_idp_from_oidc_sp_with_ial2
      sign_in_and_2fa_user(user)

      complete_doc_auth_steps_before_hybrid_handoff_step
      complete_choose_id_type_step
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
      expect(fake_analytics).not_to have_logged_event(
        :idv_doc_auth_submitted_pii_validation,
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

  context 'Pii validation fails' do
    before do
      allow_any_instance_of(Idv::DocPiiStateId).to receive(:zipcode).and_return(:invalid_junk)
    end

    it 'presents as a type 1 error' do
      stub_docv_verification_data_pass(docv_transaction_token: @docv_transaction_token, user:)

      visit_idp_from_oidc_sp_with_ial2
      sign_in_and_2fa_user(user)

      complete_doc_auth_steps_before_hybrid_handoff_step
      complete_choose_id_type_step
      click_idv_continue

      socure_docv_upload_documents(
        docv_transaction_token: @docv_transaction_token,
      )
      visit idv_socure_document_capture_update_path

      expect(page).to have_content(t('doc_auth.headers.unreadable_id'))
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
      allow(IdentityConfig.store).to receive_messages(
        allowed_biometric_ial_providers: [service_provider.issuer],
        allowed_valid_authn_contexts_semantic_providers: [service_provider.issuer],
        doc_auth_selfie_desktop_test_mode: false,
        doc_auth_vendor_lexis_nexis_percent: 0,
        doc_auth_vendor_socure_percent: 100,
        doc_auth_vendor_switching_enabled: true,
        in_person_proofing_enabled: true,
        in_person_proofing_opt_in_enabled: in_person_proofing_opt_in_enabled,
        socure_docv_enabled: true,
      )
      allow_any_instance_of(ServiceProvider).to receive(:in_person_proofing_enabled)
        .and_return(false)
      reload_ab_tests

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
      let(:facial_match_required) { true }

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
