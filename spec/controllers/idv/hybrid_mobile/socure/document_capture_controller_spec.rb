require 'rails_helper'

RSpec.describe Idv::HybridMobile::Socure::DocumentCaptureController do
  include FlowPolicyHelper

  let(:idv_vendor) { Idp::Constants::Vendors::SOCURE }
  let(:fake_socure_endpoint) { 'https://fake-socure.test' }
  let(:user) { create(:user) }
  let(:stored_result) { nil }
  let(:socure_docv_enabled) { true }
  let(:socure_docv_verification_data_test_mode) { false }

  let(:document_capture_session) do
    DocumentCaptureSession.create(
      user: user,
      requested_at: Time.zone.now,
      doc_auth_vendor: idv_vendor,
    )
  end
  let(:document_capture_session_uuid) { document_capture_session&.uuid }
  let(:no_url_socure_route) do
    idv_hybrid_mobile_socure_document_capture_errors_url(error_code: :url_not_found)
  end
  let(:timeout_socure_route) do
    idv_hybrid_mobile_socure_document_capture_errors_url(error_code: :timeout)
  end
  let(:idv_socure_docv_flow_id_only) { 'id only flow' }
  let(:idv_socure_docv_flow_id_w_selfie) { 'selfie flow' }

  before do
    allow(IdentityConfig.store).to receive(:socure_docv_enabled)
      .and_return(socure_docv_enabled)
    allow(IdentityConfig.store).to receive(:socure_docv_document_request_endpoint)
      .and_return(fake_socure_endpoint)
    allow(IdentityConfig.store).to receive(:idv_socure_docv_flow_id_w_selfie)
      .and_return(idv_socure_docv_flow_id_w_selfie)
    allow(IdentityConfig.store).to receive(:idv_socure_docv_flow_id_only)
      .and_return(idv_socure_docv_flow_id_only)

    allow(subject).to receive(:stored_result).and_return(stored_result)

    session[:doc_capture_user_id] = user&.id
    session[:document_capture_session_uuid] = document_capture_session_uuid

    allow(IdentityConfig.store)
      .to receive(:socure_docv_verification_data_test_mode)
      .and_return(socure_docv_verification_data_test_mode)

    unless IdentityConfig.store.socure_docv_verification_data_test_mode
      expect(IdentityConfig.store).not_to receive(:socure_docv_verification_data_test_mode_tokens)
    end

    stub_analytics
  end

  describe 'before_actions' do
    it 'checks valid document capture session' do
      expect(subject).to have_actions(
        :before,
        :check_valid_document_capture_session,
      )
    end
  end

  describe '#show' do
    let(:request_class) { DocAuth::Socure::Requests::DocumentRequest }

    let(:expected_language) { :en }
    let(:response_body) { {} }

    before do
      stub_request(:post, fake_socure_endpoint).to_return(
        status: 200,
        body: JSON.generate(response_body),
      )
    end

    context 'with no user id in session' do
      let(:document_capture_session) { nil }
      let(:user) { nil }

      it 'redirects to root' do
        get :show
        expect(response).to redirect_to root_url
      end
    end

    context 'when we try to use this controller but we should be using the LN/mock version' do
      context 'when doc_auth_vendor is Lexis Nexis' do
        let(:idv_vendor) { Idp::Constants::Vendors::LEXIS_NEXIS }

        it 'redirects to the LN/mock controller' do
          get :show
          expect(response).to redirect_to idv_hybrid_mobile_document_capture_url
        end
      end
    end

    context 'happy path' do
      let(:socure_capture_app_url) { 'https://verify.socure.test/' }
      let(:docv_transaction_token) { '176dnc45d-2e34-46f3-82217-6f540ae90673' }
      let(:response_body) do
        {
          referenceId: '123ab45d-2e34-46f3-8d17-6f540ae90303',
          data: {
            eventId: 'zoYgIxEZUbXBoocYAnbb5DrT',
            docvTransactionToken: docv_transaction_token,
            qrCode: 'data:image/png;base64,iVBO......K5CYII=',
            url: socure_capture_app_url,
          },
        }
      end

      before do
        allow(I18n).to receive(:locale).and_return(expected_language)
        allow(request_class).to receive(:new).and_call_original
        allow(request_class).to receive(:handle_connection_error).and_call_original
      end

      context 'selfie not required' do
        before do
          get(:show)
        end

        it 'correctly logs idv_doc_auth_document_capture_visited' do
          expect(@analytics).to have_logged_event(
            'IdV: doc auth document_capture visited',
            hash_including(
              step: 'socure_document_capture',
              flow_path: 'hybrid',
            ),
          )
        end

        it 'creates a DocumentRequest' do
          expect(request_class).to have_received(:new)
            .with(
              customer_user_id: user.uuid,
              passport_requested: false,
              redirect_url: idv_hybrid_mobile_socure_document_capture_update_url,
              language: expected_language,
              liveness_checking_required: false,
            )
        end

        it 'sets any docv timeouts to nil' do
          expect(session[:socure_docv_wait_polling_started_at]).to eq nil
        end

        it 'logs correct info' do
          expect(@analytics).to have_logged_event(
            :idv_socure_document_request_submitted,
          )
        end

        it 'sets DocumentCaptureSession socure_docv_capture_app_url value' do
          document_capture_session.reload
          expect(document_capture_session.socure_docv_capture_app_url).to eq(socure_capture_app_url)
        end

        context 'language is english' do
          let(:expected_language) { :en }

          it 'does the correct POST to Socure' do
            expect(WebMock).to have_requested(:post, fake_socure_endpoint)
              .with(
                body: JSON.generate(
                  {
                    config: {
                      documentType: 'license',
                      redirect: {
                        method: 'GET',
                        url: idv_hybrid_mobile_socure_document_capture_update_url,
                      },
                      language: expected_language,
                      useCaseKey: IdentityConfig.store.idv_socure_docv_flow_id_only,
                    },
                    customerUserId: user.uuid,
                  },
                ),
              )
          end
        end

        context 'language is chinese and language should be zn-ch' do
          let(:expected_language) { :zh }

          it 'does the correct POST to Socure' do
            expect(WebMock).to have_requested(:post, fake_socure_endpoint)
              .with(
                body: JSON.generate(
                  {
                    config: {
                      documentType: 'license',
                      redirect: {
                        method: 'GET',
                        url: idv_hybrid_mobile_socure_document_capture_update_url,
                      },
                      language: 'zh-cn',
                      useCaseKey: IdentityConfig.store.idv_socure_docv_flow_id_only,
                    },
                    customerUserId: user.uuid,
                  },
                ),
              )
          end
        end

        context 'renders the interstital page' do
          render_views

          it 'response includes the socure capture app url' do
            expect(response).to have_http_status 200
            expect(response.body).to have_link(href: socure_capture_app_url)
          end

          it 'puts the docvTransactionToken into the document capture session' do
            document_capture_session.reload
            expect(document_capture_session.socure_docv_transaction_token)
              .to eq(docv_transaction_token)
          end

          context 'when we try to use this controller but we should be using the LN/mock version' do
            let(:idv_vendor) { Idp::Constants::Vendors::LEXIS_NEXIS }

            it 'redirects to the LN/Mock controller' do
              get :show

              expect(response).to redirect_to(idv_hybrid_mobile_document_capture_url)
            end

            context 'when redirect to correct vendor is disabled' do
              before do
                allow(IdentityConfig.store)
                  .to receive(:doc_auth_redirect_to_correct_vendor_disabled).and_return(true)
              end

              it 'renders to the Socure controller' do
                get :show

                expect(response).to have_http_status 200
                expect(response.body).to have_link(href: socure_capture_app_url)
              end
            end
          end
        end
      end

      context 'selfie required' do
        before do
          authn_context_result = Vot::Parser.new(vector_of_trust: 'Pb').parse
          allow(subject).to receive(:resolved_authn_context_result).and_return(authn_context_result)
          get(:show)
        end

        it 'request the flow for selfie' do
          expect(WebMock).to have_requested(:post, fake_socure_endpoint)
            .with(
              body: JSON.generate(
                {
                  config: {
                    documentType: 'license',
                    redirect: {
                      method: 'GET',
                      url: idv_hybrid_mobile_socure_document_capture_update_url,
                    },
                    language: expected_language,
                    useCaseKey: IdentityConfig.store.idv_socure_docv_flow_id_w_selfie,
                  },
                  customerUserId: user.uuid,
                },
              ),
            )
        end
      end
    end

    context 'there is no url in the socure response' do
      let(:response_body) { {} }

      it 'redirects to idv unavailable url' do
        get(:show)

        expect(response).to redirect_to(no_url_socure_route)
        expect(controller.send(:instance_variable_get, :@url)).not_to be
      end
    end

    context 'when socure is disabled' do
      let(:socure_docv_enabled) { false }
      it 'the webhook route does not exist' do
        get(:show)

        expect(response).to be_not_found
      end
    end

    context 'when socure error encountered' do
      let(:fake_socure_endpoint) { 'https://fake-socure.test/' }
      let(:failed_response_body) do
        { 'status' => 'Error',
          'referenceId' => '1cff6d33-1cc0-4205-b740-c9a9e6b8bd66',
          'data' => {},
          'msg' => 'No active account is associated with this request' }
      end
      let(:response_body_401) do
        {
          status: 'Error',
          referenceId: '7ff0cdc5-395e-45d1-8467-0ff1b41c11dc',
          msg: 'string',
        }
      end
      let(:no_doc_found_response_body) do
        {
          referenceId: '0dc21b0d-04df-4dd5-8533-ec9ecdafe0f4',
          msg: {
            status: 400,
            msg: 'No Documents found',
          },
        }
      end
      before do
        allow(IdentityConfig.store).to receive(:socure_docv_document_request_endpoint)
          .and_return(fake_socure_endpoint)
      end
      it 'connection timeout still responds to user' do
        stub_request(:post, fake_socure_endpoint).to_raise(Faraday::ConnectionFailed)
        get(:show)
        expect(response).to redirect_to(no_url_socure_route)
      end

      it 'socure error response still gives a result to user' do
        stub_request(:post, fake_socure_endpoint).to_return(
          status: 401,
          body: JSON.generate(failed_response_body),
        )
        get(:show)
        expect(response).to redirect_to(no_url_socure_route)
      end

      it 'socure nil response still gives a result to user' do
        stub_request(:post, fake_socure_endpoint).to_return(
          status: 500,
          body: nil,
        )
        get(:show)
        expect(response).to redirect_to(no_url_socure_route)
      end

      it 'socure nil response still gives a result to user' do
        stub_request(:post, fake_socure_endpoint).to_return(
          status: 401,
          body: JSON.generate(response_body_401),
        )
        get(:show)
        expect(response).to redirect_to(no_url_socure_route)
      end

      it 'socure nil response still gives a result to user' do
        stub_request(:post, fake_socure_endpoint).to_return(
          status: 401,
          body: JSON.generate(no_doc_found_response_body),
        )
        get(:show)
        expect(response).to redirect_to(no_url_socure_route)
      end
    end
    context 'reuse of valid capture app urls when appropriate' do
      let(:fake_capture_app_url) { 'https://verify.socure.test/fake_capture_app' }
      let(:socure_capture_app_url) { 'https://verify.socure.test/' }
      let(:docv_transaction_token) { '176dnc45d-2e34-46f3-82217-6f540ae90673' }
      let(:response_body) do
        {
          referenceId: '123ab45d-2e34-46f3-8d17-6f540ae90303',
          data: {
            eventId: 'zoYgIxEZUbXBoocYAnbb5DrT',
            docvTransactionToken: docv_transaction_token,
            qrCode: 'data:image/png;base64,iVBO......K5CYII=',
            url: socure_capture_app_url,
          },
        }
      end

      before do
        allow(request_class).to receive(:new).and_call_original
        allow(I18n).to receive(:locale).and_return(expected_language)
      end

      it 'does not create a DocumentRequest when valid capture app exists' do
        dcs = create(
          :document_capture_session,
          uuid: user.id,
          socure_docv_capture_app_url: fake_capture_app_url,
        )
        allow(DocumentCaptureSession).to receive(:find_by).and_return(dcs)
        get(:show)
        expect(request_class).not_to have_received(:new)
        expect(dcs.socure_docv_capture_app_url).to eq(fake_capture_app_url)
      end
    end
  end

  describe '#update' do
    let(:stored_result) do
      DocumentCaptureSessionResult.new(
        success: true,
        selfie_status: 'not_processed',
        pii: { state: 'MD' },
      )
    end

    before do
      stub_sign_in(user)
      allow(subject.document_capture_session).to receive(:load_result).and_return(stored_result)
    end

    it 'redirects to the capture complete page' do
      get(:update)

      expect(response).to redirect_to(idv_hybrid_mobile_capture_complete_url)
      expect(@analytics).to have_logged_event('IdV: doc auth document_capture submitted')
    end

    context 'when socure is disabled' do
      let(:socure_docv_enabled) { false }

      it 'the webhook route does not exist' do
        get(:update)

        expect(response).to be_not_found
      end
    end

    context 'when socure reports failure' do
      let(:stored_result) do
        DocumentCaptureSessionResult.new(
          success: false,
          selfie_status: 'not_processed',
          pii: { state: 'MD' },
        )
      end

      it 'redirects to the error page' do
        get(:update)

        expect(response).to redirect_to(idv_hybrid_mobile_socure_document_capture_errors_url)
        expect(@analytics).to have_logged_event('IdV: doc auth document_capture submitted')
      end
    end

    context 'when stored result is nil' do
      let(:stored_result) { nil }

      it 'renders the wait view' do
        get(:update)

        expect(response).to render_template('idv/socure/document_capture/wait')
        expect(@analytics).to have_logged_event(:idv_doc_auth_document_capture_polling_wait_visited)
      end

      context 'when the wait times out' do
        before do
          allow(subject).to receive(:wait_timed_out?).and_return(true)
        end

        it 'redirects to the hybrid mobile socure errors timeout page' do
          get(:update)
          expect(response).to redirect_to(timeout_socure_route)
        end
      end
    end

    context 'when socure_docv_verification_data_test_mode is enabled' do
      let(:test_token) { '12345' }
      let(:socure_docv_verification_data_test_mode) { true }

      before do
        ActiveJob::Base.queue_adapter = :test
        allow(IdentityConfig.store)
          .to receive(:socure_docv_verification_data_test_mode_tokens)
          .and_return([test_token])

        stub_request(
          :post,
          "#{IdentityConfig.store.socure_idplus_base_url}/api/3.0/EmailAuthScore",
        )
          .with(body: {
            modules: ['documentverification'],
            docvTransactionToken: test_token,
            customerUserId: user.uuid,
            email: user.email,
          }
            .to_json)
          .to_return(
            headers: {
              'Content-Type' => 'application/json',
            },
            body: SocureDocvFixtures.pass_json,
          )
      end

      context 'when a token is provided from the allow list' do
        it 'performs SocureDocvResultsJob' do
          expect { get(:update, params: { docv_token: test_token }) }
            .not_to have_enqueued_job(SocureDocvResultsJob) # is synchronous

          expect(document_capture_session.reload.load_result).not_to be_nil
        end
      end

      context 'when a token is provided not on the allow list' do
        it 'performs SocureDocvResultsJob' do
          expect { get(:update, params: { docv_token: 'rando-token' }) }
            .not_to have_enqueued_job(SocureDocvResultsJob)

          expect(document_capture_session.reload.load_result).to be_nil
        end
      end
    end
  end
end
