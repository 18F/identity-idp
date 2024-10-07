require 'rails_helper'

RSpec.describe Idv::Socure::DocumentCaptureController do
  include FlowPolicyHelper

  let(:idv_vendor) { Idp::Constants::Vendors::SOCURE }
  let(:fake_socure_endpoint) { 'https://fake-socure.com' }
  let(:user) { create(:user) }
  let(:stored_result) { nil }

  let(:document_capture_session) do
    DocumentCaptureSession.create(
      user: user,
      requested_at: Time.zone.now,
    )
  end

  before do
    allow(IdentityConfig.store).to receive(:socure_document_request_endpoint).
      and_return(fake_socure_endpoint)
    allow(IdentityConfig.store).to receive(:doc_auth_vendor).and_return(idv_vendor)
    allow(IdentityConfig.store).to receive(:doc_auth_vendor_default).and_return(idv_vendor)

    allow(subject).to receive(:stored_result).and_return(stored_result)

    user_session = {}
    allow(subject).to receive(:user_session).and_return(user_session)

    subject.idv_session.document_capture_session_uuid = document_capture_session.uuid
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

    context 'happy path' do
      let(:response_redirect_url) { 'https://boogie-woogie.com/dance' }
      let(:docv_transaction_token) { '176dnc45d-2e34-46f3-82217-6f540ae90673' }
      let(:response_body) do
        {
          referenceId: '123ab45d-2e34-46f3-8d17-6f540ae90303',
          data: {
            eventId: 'zoYgIxEZUbXBoocYAnbb5DrT',
            customerUserId: '121212',
            docvTransactionToken: docv_transaction_token,
            qrCode: 'data:image/png;base64,iVBO......K5CYII=',
            url: response_redirect_url,
          },
        }
      end

      before do
        allow(request_class).to receive(:new).and_call_original
        allow(I18n).to receive(:locale).and_return(expected_language)
        get(:show)
      end

      it 'creates a DocumentRequest' do
        expect(request_class).to have_received(:new).
          with(
            document_capture_session_uuid: expected_uuid,
            redirect_url: idv_socure_document_capture_url,
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
                      url: idv_socure_document_capture_url,
                    },
                    language: :en,
                  },
                  customerUserId: expected_uuid,
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
                      url: idv_socure_document_capture_url,
                    },
                    language: 'zh-cn',
                  },
                  customerUserId: expected_uuid,
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
          expect(document_capture_session.socure_docv_token).to eq(docv_transaction_token)
        end
      end
    end

    context 'when we should not redirect because there is no url in the response' do
      let(:response_body) { {} }

      it 'does not redirect' do
        expect(response).not_to have_http_status(:redirect)
        expect(controller.send(:instance_variable_get, :@url)).not_to be
      end
    end
  end

  describe '#update' do
    it 'returns OK (200)' do
      post(:update)

      expect(response).to have_http_status(:ok)
    end
  end
end
