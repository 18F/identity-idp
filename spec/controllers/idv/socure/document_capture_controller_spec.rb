require 'rails_helper'

RSpec.describe Idv::Socure::DocumentCaptureController do
  include FlowPolicyHelper

  let(:idv_vendor) { Idp::Constants::Vendors::SOCURE }
  let(:fake_socure_endpoint) { 'https://fake-socure.test' }
  let(:user) { create(:user) }
  let(:doc_auth_success) { true }
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
  let(:socure_enabled) { true }

  let(:document_capture_session) do
    DocumentCaptureSession.create(
      user: user,
      requested_at: Time.zone.now,
    )
  end

  before do
    allow(IdentityConfig.store).to receive(:socure_enabled).
      and_return(socure_enabled)
    allow(IdentityConfig.store).to receive(:socure_document_request_endpoint).
      and_return(fake_socure_endpoint)
    allow(IdentityConfig.store).to receive(:doc_auth_vendor).and_return(idv_vendor)
    allow(IdentityConfig.store).to receive(:doc_auth_vendor_default).and_return(idv_vendor)
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)

    allow(subject).to receive(:stored_result).and_return(stored_result)

    user_session = {}
    allow(subject).to receive(:user_session).and_return(user_session)

    subject.idv_session.document_capture_session_uuid = document_capture_session.uuid

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
    let(:expected_uuid) { document_capture_session.uuid }
    let(:expected_language) { :en }
    let(:response_body) { {} }

    before do
      stub_request(:post, fake_socure_endpoint).to_return(
        status: 200,
        body: JSON.generate(response_body),
      )

      stub_sign_in(user)
      stub_up_to(:hybrid_handoff, idv_session: subject.idv_session)

      subject.idv_session.document_capture_session_uuid = expected_uuid
    end

    context 'when we try to use this controller but we should be using the LN/mock version' do
      let(:idv_vendor) { Idp::Constants::Vendors::LEXIS_NEXIS }

      it 'redirects to the LN/mock controller' do
        get :show
        expect(response).to redirect_to idv_document_capture_url
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
        allow(DocumentCaptureSession).to receive(:find_by).and_return(document_capture_session)
        get(:show)
      end

      it 'creates a DocumentRequest' do
        expect(request_class).to have_received(:new).
          with(
            redirect_url: idv_socure_document_capture_update_url,
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
                      url: idv_socure_document_capture_update_url,
                    },
                    language: :en,
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
                      url: idv_socure_document_capture_update_url,
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
      let(:socure_enabled) { false }
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
        allow(IdentityConfig.store).to receive(:socure_document_request_endpoint).
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
    it 'returns FOUND (302) and redirects to SSN' do
      get(:update)

      expect(response).to redirect_to(idv_ssn_path)
      expect(@analytics).to have_logged_event('IdV: doc auth document_capture submitted')
    end

    context 'when doc auth fails' do
      let(:doc_auth_success) { false }

      it 'redirects to document capture' do
        get(:update)

        expect(response).to redirect_to(idv_socure_document_capture_path)
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
    end

    context 'when socure is disabled' do
      let(:socure_enabled) { false }

      it 'the webhook route does not exist' do
        get(:update)

        expect(response).to be_not_found
      end
    end
  end
end
