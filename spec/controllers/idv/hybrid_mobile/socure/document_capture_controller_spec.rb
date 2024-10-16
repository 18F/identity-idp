require 'rails_helper'

RSpec.describe Idv::HybridMobile::Socure::DocumentCaptureController do
  include FlowPolicyHelper

  let(:idv_vendor) { Idp::Constants::Vendors::SOCURE }
  let(:fake_socure_endpoint) { 'https://fake-socure.com' }
  let(:user) { create(:user) }
  let(:stored_result) { nil }
  let(:socure_enabled) { true }

  let(:document_capture_session) do
    DocumentCaptureSession.create(
      user: user,
      requested_at: Time.zone.now,
    )
  end
  let(:document_capture_session_uuid) { document_capture_session&.uuid }

  before do
    allow(IdentityConfig.store).to receive(:socure_enabled).
      and_return(socure_enabled)
    allow(IdentityConfig.store).to receive(:socure_document_request_endpoint).
      and_return(fake_socure_endpoint)
    allow(IdentityConfig.store).to receive(:doc_auth_vendor).and_return(idv_vendor)
    allow(IdentityConfig.store).to receive(:doc_auth_vendor_default).and_return(idv_vendor)

    allow(subject).to receive(:stored_result).and_return(stored_result)
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

      session[:doc_capture_user_id] = user&.id
      session[:document_capture_session_uuid] = document_capture_session_uuid
    end

    context 'with no user id in session' do
      let(:document_capture_session) { nil }
      let(:user) { nil }

      it 'redirects to root' do
        get :show
        expect(response).to redirect_to root_url
      end
    end

    context 'happy path' do
      let(:response_redirect_url) { 'https://idv.test/dance' }
      let(:docv_transaction_token) { '176dnc45d-2e34-46f3-82217-6f540ae90673' }
      let(:response_body) do
        {
          referenceId: '123ab45d-2e34-46f3-8d17-6f540ae90303',
          data: {
            eventId: 'zoYgIxEZUbXBoocYAnbb5DrT',
            customerUserId: document_capture_session_uuid,
            docvTransactionToken: docv_transaction_token,
            qrCode: 'data:image/png;base64,iVBO......K5CYII=',
            url: response_redirect_url,
          },
        }
      end

      before do
        allow(I18n).to receive(:locale).and_return(expected_language)
        allow(request_class).to receive(:new).and_call_original
        get(:show)
      end

      it 'creates a DocumentRequest' do
        expect(request_class).to have_received(:new).
          with(
            document_capture_session_uuid: document_capture_session_uuid,
            redirect_url: idv_hybrid_mobile_socure_document_capture_url,
            language: expected_language,
          )
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
                      method: 'POST',
                      url: idv_hybrid_mobile_socure_document_capture_url,
                    },
                    language: expected_language,
                  },
                  customerUserId: document_capture_session_uuid,
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
                      method: 'POST',
                      url: idv_hybrid_mobile_socure_document_capture_url,
                    },
                    language: 'zh-cn',
                  },
                  customerUserId: document_capture_session_uuid,
                },
              ),
            )
        end
      end

      context 'renders the interstital page' do
        render_views

        it 'it includes the socure redirect url' do
          expect(response).to have_http_status 200
          expect(response.body).to have_link(href: response_redirect_url)
        end

        it 'puts the docvTransactionToken into the document capture session' do
          document_capture_session.reload
          expect(document_capture_session.socure_docv_transaction_token).
            to eq(docv_transaction_token)
        end
      end
    end

    context 'when we should not redirect because there is no url in the response' do
      let(:response_body) { {} }

      it 'does not redirect' do
        get(:show)

        expect(response).not_to have_http_status(:redirect)
        expect(controller.send(:instance_variable_get, :@url)).not_to be
      end
    end

    context 'when socure is disabled' do
      let(:socure_enabled) { false }
      it 'the webhook route does not exist' do
        get(:show)

        expect(response).to be_not_found
      end
    end
  end

  describe '#update' do
    it 'returns OK (200)' do
      post(:update)

      expect(response).to have_http_status(:ok)
    end

    context 'when socure is disabled' do
      let(:socure_enabled) { false }
      it 'the webhook route does not exist' do
        post(:update)

        expect(response).to be_not_found
      end
    end
  end
end
