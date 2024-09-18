require 'rails_helper'

RSpec.describe Idv::Socure::DocumentCaptureController do
  include FlowPolicyHelper

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
    let(:idv_vendor) { Idp::Constants::Vendors::SOCURE }
    let(:fake_socure_endpoint) { 'https://fake-socure.com' }
    let(:request_class) { DocAuth::Socure::Requests::DocumentRequest }

    let(:user) { create(:user) }

    let(:expected_uuid) { 'document_capture_session_uuid' }
    let(:expected_redirect_url) { idv_socure_document_capture_url }
    let(:expected_language) { :en }
    let(:expected_request_body) do
      JSON.generate(
        {
          config: {
            documentType: 'license',
            redirect: {
              method: 'POST',
              url: expected_redirect_url,
            },
            language: expected_language,
          },
          customerUserId: expected_uuid,
        },
      )
    end

    before do
      allow(IdentityConfig.store).to receive(:socure_document_request_endpoint).
        and_return(fake_socure_endpoint)
      allow(IdentityConfig.store).to receive(:doc_auth_vendor).and_return(idv_vendor)
      allow(IdentityConfig.store).to receive(:doc_auth_vendor_default).and_return(idv_vendor)
      # allow(request).to receive(:endpoint).and_return(fake_socure_endpoint)
      # allow(request).to receive(:metric_name).and_return(fake_metric_name)
    end

    it 'creates a DocumentRequest' do
      allow(request_class).to receive(:new).
        with(any_args).
        and_call_original

      stub_request(:post, 'https://fake-socure.com/').
        with(body: expected_request_body).
        to_return(status: 200, body: '{}', headers: {})

      stub_sign_in(user)
      stub_up_to(:hybrid_handoff, idv_session: subject.idv_session)

      # stub_analytics

      subject.idv_session.document_capture_session_uuid = expected_uuid

      # vot = sp_selfie_enabled ? 'Pb' : 'P1'
      # resolved_authn_context = Vot::Parser.new(vector_of_trust: vot).parse

      # allow(controller).to receive(:resolved_authn_context_result).
      #   and_return(resolved_authn_context)

      # subject.idv_session.flow_path = flow_path

      # allow(subject).to receive(:ab_test_analytics_buckets).and_return(ab_test_args)

      get(:show)

      expect(request_class).to have_received(:new).
        with(
          document_capture_session_uuid: expected_uuid,
          redirect_url: idv_socure_document_capture_url,
          language: expected_language,
        )
    end

    context 'when we should redirect' do
      let(:response_redirect_url) { 'https://boogie-woogie.com/dance' }

      it 'redirects' do
        allow(request_class).to receive(:new).
          with(any_args).
          and_call_original

        stub_request(:post, 'https://fake-socure.com/').
          with(body: expected_request_body).
          to_return(
            status: 200,
            body: JSON.generate({ data: { url: response_redirect_url } }),
            headers: {},
          )

        stub_sign_in(user)
        stub_up_to(:hybrid_handoff, idv_session: subject.idv_session)

        # stub_analytics

        subject.idv_session.document_capture_session_uuid = expected_uuid

        # vot = sp_selfie_enabled ? 'Pb' : 'P1'
        # resolved_authn_context = Vot::Parser.new(vector_of_trust: vot).parse

        # allow(controller).to receive(:resolved_authn_context_result).
        #   and_return(resolved_authn_context)

        # subject.idv_session.flow_path = flow_path

        # allow(subject).to receive(:ab_test_analytics_buckets).and_return(ab_test_args)

        get(:show)
        expect(response).to redirect_to(response_redirect_url)
      end
    end

    context 'when we should not redirect' do
      it 'does not redirect' do
        allow(request_class).to receive(:new).
          with(any_args).
          and_call_original

        stub_request(:post, 'https://fake-socure.com/').
          with(body: expected_request_body).
          to_return(status: 200, body: '{}', headers: {})

        stub_sign_in(user)
        stub_up_to(:hybrid_handoff, idv_session: subject.idv_session)

        # stub_analytics

        subject.idv_session.document_capture_session_uuid = expected_uuid

        # vot = sp_selfie_enabled ? 'Pb' : 'P1'
        # resolved_authn_context = Vot::Parser.new(vector_of_trust: vot).parse

        # allow(controller).to receive(:resolved_authn_context_result).
        #   and_return(resolved_authn_context)

        # subject.idv_session.flow_path = flow_path

        # allow(subject).to receive(:ab_test_analytics_buckets).and_return(ab_test_args)

        get(:show)

        expect(response).not_to have_http_status(:redirect)
      end
    end
  end

  describe '#update' do
    it 'tests some things'
  end
end
