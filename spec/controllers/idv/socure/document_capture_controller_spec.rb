require 'rails_helper'

RSpec.describe Idv::Socure::DocumentCaptureController do
  include FlowPolicyHelper

  let(:idv_vendor) { Idp::Constants::Vendors::SOCURE }
  let(:vendor_switching_enabled) { true }
  let(:fake_socure_endpoint) { 'https://fake-socure.test' }
  let(:user) { create(:user) }
  let(:doc_auth_success) { true }
  let(:socure_docv_enabled) { true }
  let(:socure_docv_verification_data_test_mode) { false }
  let(:no_url_socure_route) { idv_socure_document_capture_errors_url(error_code: :url_not_found) }
  let(:timeout_socure_route) { idv_socure_document_capture_errors_url(error_code: :timeout) }
  let(:idv_socure_docv_flow_id_only) { 'id only flow' }
  let(:idv_socure_docv_flow_id_w_selfie) { 'selfie flow' }

  let(:stored_result) do
    DocumentCaptureSessionResult.new(
      id: SecureRandom.uuid,
      success: doc_auth_success,
      doc_auth_success: doc_auth_success,
      selfie_status: :none,
      pii: { first_name: 'Testy', last_name: 'Testerson' },
      attention_with_barcode: false,
    )
  end

  before do
    document_capture_session = create(
      :document_capture_session,
      user:,
      requested_at: Time.zone.now,
      doc_auth_vendor: idv_vendor,
    )
    allow(IdentityConfig.store).to receive(:socure_docv_enabled)
      .and_return(socure_docv_enabled)
    allow(IdentityConfig.store).to receive(:socure_docv_document_request_endpoint)
      .and_return(fake_socure_endpoint)
    allow(IdentityConfig.store).to receive(:doc_auth_vendor).and_return(idv_vendor)
    allow(IdentityConfig.store).to receive(:doc_auth_vendor_default).and_return(idv_vendor)
    allow(IdentityConfig.store).to receive(:doc_auth_vendor_switching_enabled)
      .and_return(vendor_switching_enabled)
    allow(IdentityConfig.store).to receive(:doc_auth_selfie_vendor_default).and_return(idv_vendor)
    allow(IdentityConfig.store).to receive(:doc_auth_selfie_vendor_switching_enabled)
      .and_return(vendor_switching_enabled)
    allow(IdentityConfig.store).to receive(:idv_socure_docv_flow_id_w_selfie)
      .and_return(idv_socure_docv_flow_id_w_selfie)
    allow(IdentityConfig.store).to receive(:idv_socure_docv_flow_id_only)
      .and_return(idv_socure_docv_flow_id_only)
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow(subject).to receive(:stored_result).and_return(stored_result)

    user_session = {}
    allow(subject).to receive(:user_session).and_return(user_session)

    subject.idv_session.document_capture_session_uuid = document_capture_session.uuid
    allow(IdentityConfig.store)
      .to receive(:socure_docv_verification_data_test_mode)
      .and_return(socure_docv_verification_data_test_mode)

    unless IdentityConfig.store.socure_docv_verification_data_test_mode
      expect(IdentityConfig.store).not_to receive(:socure_docv_verification_data_test_mode_tokens)
    end

    stub_analytics
  end

  describe '#step_info' do
    it 'returns a valid StepInfo object' do
      expect(described_class.step_info).to be_valid
    end
  end

  describe 'before_actions' do
    it 'includes authentication before_action' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated,
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

      stub_sign_in(user)
      stub_up_to(:hybrid_handoff, idv_session: subject.idv_session)
    end

    context 'when we try to use this controller but we should be using the LN/mock version' do
      context 'when doc_auth_vendor is Lexis Nexis' do
        let(:idv_vendor) { Idp::Constants::Vendors::LEXIS_NEXIS }

        it 'redirects to the LN/mock controller' do
          get :show
          expect(response).to redirect_to idv_document_capture_url
        end

        context 'when redirect to correct vendor is disabled' do
          let(:socure_capture_app_url) { 'https://verify.socure.test/' }
          let(:response_body) do
            {
              data: {
                docvTransactionToken: SecureRandom.hex(6),
                url: socure_capture_app_url,
              },
            }
          end
          before do
            allow(IdentityConfig.store)
              .to receive(:doc_auth_redirect_to_correct_vendor_disabled).and_return(true)
          end

          it 'redirects to the Socure controller' do
            get :show

            expect(response).to have_http_status 200
          end
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
        allow(request_class).to receive(:new).and_call_original
        allow(I18n).to receive(:locale).and_return(expected_language)
      end

      context 'selfie not required' do
        before do
          get(:show)
        end
        it 'creates a DocumentRequest' do
          expect(request_class).to have_received(:new)
            .with(
              customer_user_id: user.uuid,
              passport_requested: false,
              redirect_url: idv_socure_document_capture_update_url,
              language: expected_language,
              liveness_checking_required: false,
            )
        end

        it 'sets any docv timeouts to nil' do
          expect(subject.idv_session.socure_docv_wait_polling_started_at).to eq nil
        end

        it 'logs correct info' do
          expect(@analytics).to have_logged_event(
            :idv_socure_document_request_submitted,
          )
        end

        it 'sets DocumentCaptureSession socure_docv_capture_app_url value' do
          expect(subject.document_capture_session.reload.socure_docv_capture_app_url)
            .to eq(socure_capture_app_url)
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
                        url: idv_socure_document_capture_update_url,
                      },
                      language: :en,
                      useCaseKey: idv_socure_docv_flow_id_only,
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
                        url: idv_socure_document_capture_update_url,
                      },
                      language: 'zh-cn',
                      useCaseKey: idv_socure_docv_flow_id_only,
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
            expect(subject.document_capture_session.reload.socure_docv_transaction_token)
              .to eq(docv_transaction_token)
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
                      url: idv_socure_document_capture_update_url,
                    },
                    language: :en,
                    useCaseKey: idv_socure_docv_flow_id_w_selfie,
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

      it 'redirects to the errors page' do
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
          :socure,
          user:,
          doc_auth_vendor: Idp::Constants::Vendors::SOCURE,
          socure_docv_capture_app_url: fake_capture_app_url,
        )
        allow(DocumentCaptureSession).to receive(:find_by).and_return(dcs)
        allow(dcs).to receive(:choose_document_type_changed?).and_return(false)
        get(:show)
        expect(request_class).not_to have_received(:new)
        expect(dcs.socure_docv_capture_app_url).to eq(fake_capture_app_url)
      end

      context 'user changes document type on choose id screen' do
        it 'creates a new DocumentRequest even though a valid capture app url exists' do
          dcs = create(
            :document_capture_session,
            :socure,
            user:,
            doc_auth_vendor: Idp::Constants::Vendors::SOCURE,
            socure_docv_capture_app_url: fake_capture_app_url,
          )
          allow(DocumentCaptureSession).to receive(:find_by).and_return(dcs)
          allow(dcs).to receive(:choose_document_type_changed?).and_return(true)
          get(:show)
          expect(request_class).to have_received(:new)
          expect(dcs.socure_docv_capture_app_url).to_not eq(fake_capture_app_url)
        end
      end
    end
  end

  describe '#update' do
    before do
      stub_sign_in(user)
      subject.idv_session.flow_path = 'standard'
      allow(subject.document_capture_session).to receive(:load_result).and_return(stored_result)
      get :update
    end

    context 'when doc auth succeeds' do
      it 'correctly stores doc_auth_vendor in Idv::Session' do
        expect(subject.idv_session.doc_auth_vendor).to_not be_nil
        expect(subject.idv_session.doc_auth_vendor).to match(idv_vendor)
      end

      it 'returns FOUND (302) and redirects to SSN' do
        expect(response).to redirect_to(idv_ssn_path)
        expect(@analytics).to have_logged_event('IdV: doc auth document_capture submitted')
      end
    end

    context 'when doc auth fails' do
      let(:doc_auth_success) { false }

      it 'renders the errors' do
        get(:update)

        expect(response).to redirect_to idv_socure_document_capture_errors_url
        expect(@analytics).to have_logged_event('IdV: doc auth document_capture submitted')
      end
    end

    context 'when stored_result is nil' do
      let(:stored_result) { nil }

      it 'renders the wait view' do
        get(:update)
        expect(response).to render_template('idv/socure/document_capture/wait')
        expect(@analytics).to have_logged_event(:idv_doc_auth_document_capture_polling_wait_visited)
      end

      context 'when the wait times out' do
        let(:socure_docv_transaction_token) { nil }
        let(:socure_response_body) { nil }
        before do
          ActiveJob::Base.queue_adapter = :test
          allow(subject).to receive(:wait_timed_out?).and_return(true)
          stub_request(
            :post,
            "#{IdentityConfig.store.socure_idplus_base_url}/api/3.0/EmailAuthScore",
          )
            .with(body: {
              modules: ['documentverification'],
              docvTransactionToken: socure_docv_transaction_token,
              customerUserId: user.uuid,
              email: user.email,
            }
              .to_json)
            .to_return(
              headers: {
                'Content-Type' => 'application/json',
              },
              body: socure_response_body,
            )
          allow_any_instance_of(DocumentCaptureSession).to receive(:load_result).and_call_original
        end

        it 'logs a socure webhook missing analytics event' do
          get(:update)
          expect(@analytics).to have_logged_event(
            :idv_socure_verification_webhook_missing,
          )
        end

        context 'the synchronous socure call fetches docv results' do
          let(:socure_response_body) { SocureDocvFixtures.pass_json }
          it 'has a successful result' do
            expect { get(:update) }.not_to have_enqueued_job(SocureDocvResultsJob) # is synchronous

            expect(subject.document_capture_session.reload.load_result).not_to be_nil
          end
        end

        context 'the synchronous socure call does not return anything' do
          before do
            allow(subject.document_capture_session).to receive(:load_result).and_return(nil)
          end
          it 'redirects to a Try again page' do
            get(:update)
            expect(response).to redirect_to(timeout_socure_route)
          end
        end
      end
    end

    context 'when socure is disabled' do
      let(:socure_docv_enabled) { false }

      it 'the webhook route does not exist' do
        expect(response).to be_not_found
      end
    end
  end
end
