require 'rails_helper'

RSpec.describe Idv::HybridMobile::Socure::DocumentCaptureController do
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
  let(:document_capture_session_uuid) { document_capture_session&.uuid }

  before do
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
      let(:response_redirect_url) { 'https://boogie-woogie.com/dance' }
      let(:response_body) { { data: { url: response_redirect_url } } }

      before do
        I18n.locale = expected_language
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
                      url: idv_socure_document_capture_url,
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
          expect(response.body).to include(response_redirect_url)
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
  end

  describe '#update' do
    let(:result_success) { true }
    let(:stored_result) { { success: result_success } }

    before do
      allow(stored_result).to receive(:success?).and_return(result_success)
      allow(stored_result).to receive(:attention_with_barcode?).and_return(false)
      allow(stored_result).to receive(:pii_from_doc).and_return({})
      allow(stored_result).to receive(:selfie_check_performed?).and_return(false)

      stub_request(:post, fake_socure_endpoint)
      stub_analytics

      session[:doc_capture_user_id] = user&.id
      session[:document_capture_session_uuid] = document_capture_session_uuid
    end

    context 'when we succeed' do
      let(:result_success) { true }

      it 'capture complete url' do
        put(:update)

        expect(response).to redirect_to(idv_hybrid_mobile_capture_complete_url)
      end
    end

    context 'when we fail' do
      let(:result_success) { false }

      it 'redirects back to us' do
        put(:update)

        expect(response).to redirect_to(idv_hybrid_mobile_socure_document_capture_url)
      end
    end
  end
end
