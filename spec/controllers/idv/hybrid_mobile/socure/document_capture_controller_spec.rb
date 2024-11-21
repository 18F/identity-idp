require 'rails_helper'

RSpec.describe Idv::HybridMobile::Socure::DocumentCaptureController do
  include FlowPolicyHelper

  let(:idv_vendor) { Idp::Constants::Vendors::SOCURE }
  let(:fake_socure_endpoint) { 'https://fake-socure.test' }
  let(:user) { create(:user) }
  let(:stored_result) { nil }
  let(:socure_docv_enabled) { true }

  let(:document_capture_session) do
    DocumentCaptureSession.create(
      user: user,
      requested_at: Time.zone.now,
    )
  end
  let(:document_capture_session_uuid) { document_capture_session&.uuid }

  before do
    allow(IdentityConfig.store).to receive(:socure_docv_enabled).
      and_return(socure_docv_enabled)
    allow(IdentityConfig.store).to receive(:socure_docv_document_request_endpoint).
      and_return(fake_socure_endpoint)
    allow(IdentityConfig.store).to receive(:doc_auth_vendor).and_return(idv_vendor)
    allow(IdentityConfig.store).to receive(:doc_auth_vendor_default).and_return(idv_vendor)

    allow(subject).to receive(:stored_result).and_return(stored_result)

    session[:doc_capture_user_id] = user&.id
    session[:document_capture_session_uuid] = document_capture_session_uuid
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
      let(:idv_vendor) { Idp::Constants::Vendors::LEXIS_NEXIS }

      it 'redirects to the LN/mock controller' do
        get :show
        expect(response).to redirect_to idv_hybrid_mobile_document_capture_url
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
        get(:show)
      end

      it 'creates a DocumentRequest' do
        expect(request_class).to have_received(:new).
          with(
            redirect_url: idv_hybrid_mobile_socure_document_capture_update_url,
            language: expected_language,
          )
      end

      it 'sets DocumentCaptureSession socure_docv_capture_app_url value' do
        document_capture_session.reload
        expect(document_capture_session.socure_docv_capture_app_url).to eq(socure_capture_app_url)
      end

      context 'language is english' do
        let(:expected_language) { :en }

        it 'does the correct POST to Socure' do
          expect(WebMock).to have_requested(:post, fake_socure_endpoint).
            with(
              body: JSON.generate(
                {
                  config: {
                    documentType: 'license',
                    redirect: {
                      method: 'GET',
                      url: idv_hybrid_mobile_socure_document_capture_update_url,
                    },
                    language: expected_language,
                  },
                },
              ),
            )
        end
      end

      context 'language is chinese and language should be zn-ch' do
        let(:expected_language) { :zh }

        it 'does the correct POST to Socure' do
          expect(WebMock).to have_requested(:post, fake_socure_endpoint).
            with(
              body: JSON.generate(
                {
                  config: {
                    documentType: 'license',
                    redirect: {
                      method: 'GET',
                      url: idv_hybrid_mobile_socure_document_capture_update_url,
                    },
                    language: 'zh-cn',
                  },
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
          expect(document_capture_session.socure_docv_transaction_token).
            to eq(docv_transaction_token)
        end
      end
    end

    context 'there is no url in the socure response' do
      let(:response_body) { {} }

      it 'redirects to idv unavailable url' do
        get(:show)

        expect(response).to redirect_to(idv_unavailable_path)
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
        allow(IdentityConfig.store).to receive(:socure_docv_document_request_endpoint).
          and_return(fake_socure_endpoint)
      end
      it 'connection timeout still responds to user' do
        stub_request(:post, fake_socure_endpoint).to_raise(Faraday::ConnectionFailed)
        get(:show)
        expect(response).to redirect_to(idv_unavailable_path)
      end

      it 'socure error response still gives a result to user' do
        stub_request(:post, fake_socure_endpoint).to_return(
          status: 401,
          body: JSON.generate(failed_response_body),
        )
        get(:show)
        expect(response).to redirect_to(idv_unavailable_path)
      end
      it 'socure nil response still gives a result to user' do
        stub_request(:post, fake_socure_endpoint).to_return(
          status: 500,
          body: nil,
        )
        get(:show)
        expect(response).to redirect_to(idv_unavailable_path)
      end
      it 'socure nil response still gives a result to user' do
        stub_request(:post, fake_socure_endpoint).to_return(
          status: 401,
          body: JSON.generate(response_body_401),
        )
        get(:show)
        expect(response).to redirect_to(idv_unavailable_path)
      end
      it 'socure nil response still gives a result to user' do
        stub_request(:post, fake_socure_endpoint).to_return(
          status: 401,
          body: JSON.generate(no_doc_found_response_body),
        )
        get(:show)
        expect(response).to redirect_to(idv_unavailable_path)
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
    end

    it 'redirects to the capture complete page' do
      get(:update)

      expect(response).to redirect_to(idv_hybrid_mobile_capture_complete_url)
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

      it 'redirects back to the capture page' do
        get(:update)

        expect(response).to redirect_to(idv_hybrid_mobile_socure_document_capture_url)
      end
    end
  end
end
