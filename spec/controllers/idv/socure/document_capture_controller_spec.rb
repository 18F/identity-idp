require 'rails_helper'

RSpec.describe Idv::Socure::DocumentCaptureController do
  include FlowPolicyHelper

  let(:idv_vendor) { Idp::Constants::Vendors::SOCURE }
  let(:fake_socure_endpoint) { 'https://fake-socure.com' }
  let(:user) { create(:user) }
  let(:stored_result) { nil }

  before do
    allow(IdentityConfig.store).to receive(:socure_document_request_endpoint).
      and_return(fake_socure_endpoint)
    allow(IdentityConfig.store).to receive(:doc_auth_vendor).and_return(idv_vendor)
    allow(IdentityConfig.store).to receive(:doc_auth_vendor_default).and_return(idv_vendor)

    allow(subject).to receive(:stored_result).and_return(stored_result)
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

    let(:expected_uuid) { 'document_capture_session_uuid' }
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
      let(:response_body) { { data: { url: response_redirect_url } } }

      before do
        allow(request_class).to receive(:new).and_call_original
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
                  language: expected_language,
                },
                customerUserId: expected_uuid,
              },
            ),
          )
      end

      it 'redirects' do
        expect(response).to redirect_to(response_redirect_url)
      end

      it 'allows redirects to socure' do
        form_action = response.request.content_security_policy.form_action
        expect(form_action).to include('https://verify.socure.us')
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
    let(:document_capture_session) do
      DocumentCaptureSession.create(
        user: user,
        requested_at: Time.zone.now,
      )
    end

    let(:result_success) { true }
    let(:stored_result) { { success: result_success } }

    before do
      allow(stored_result).to receive(:success?).and_return(result_success)
      allow(stored_result).to receive(:attention_with_barcode?).and_return(false)
      allow(stored_result).to receive(:pii_from_doc).and_return({})
      allow(stored_result).to receive(:selfie_check_performed?).and_return(false)

      stub_request(:post, fake_socure_endpoint)
      stub_sign_in(user)
      stub_up_to(:hybrid_handoff, idv_session: subject.idv_session)

      subject.idv_session.document_capture_session_uuid = document_capture_session.uuid
    end

    it 'invalidates the future steps' do
      allow(subject).to receive(:clear_future_steps!)

      put(:update)

      expect(subject).to have_received(:clear_future_steps!)
    end

    it 'resets redo_document_capture' do
      put(:update)

      expect(subject.idv_session.redo_document_capture).to be_nil
    end

    context 'when we succeed' do
      let(:result_success) { true }

      it 'redirects to SSN' do
        put(:update)

        expect(response).to redirect_to(idv_ssn_url)
      end
    end

    context 'when we fail' do
      let(:result_success) { false }

      it 'redirects back to us' do
        put(:update)

        expect(response).to redirect_to(idv_socure_document_capture_url)
      end
    end
  end
end
