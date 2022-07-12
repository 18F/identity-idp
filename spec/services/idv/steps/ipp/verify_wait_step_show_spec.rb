require 'rails_helper'

describe Idv::Steps::Ipp::VerifyWaitStepShow do
  include Rails.application.routes.url_helpers

  let(:user) { build(:user) }
  let(:issuer) { 'test_issuer' }
  let(:service_provider) { create(:service_provider) }
  let(:controller) do
    instance_double(
      # do we need all of these?
      'controller',
      analytics: FakeAnalytics.new,
      current_sp: service_provider,
      current_user: user,
      flash: {},
      request: double(
        'request',
        headers: {
          'X-Amzn-Trace-Id' => amzn_trace_id,
        },
      ),
      poll_with_meta_refresh: nil,
      session: { sp: { issuer: service_provider.issuer } },
      url_options: {},
    )
  end
  let(:service_provider) { build(:service_provider, issuer: issuer) }
  let(:amzn_trace_id) { SecureRandom.uuid }
  let(:result) do
    {
      context: { stages: { resolution: {} } },
      errors: {},
      exception: nil,
      success: true,
    }
  end
  let(:document_capture_session) {
    document_capture_session = DocumentCaptureSession.create!(user: user)
    document_capture_session.create_proofing_session
    document_capture_session.store_proofing_result(result)
    document_capture_session
  }
  let(:dcs_uuid) { document_capture_session.uuid }

  let(:pii) do
    Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN.dup
  end

  let(:flow_session) do
    {
      idv_verify_step_document_capture_session_uuid: dcs_uuid,
      'Idv::Steps::Ipp::VerifyStep' => true,
      pii_from_user: pii,
    }
  end

  let(:flow) do
    Idv::Flows::InPersonFlow.new(controller, {}, 'idv/in_person').tap do |flow|
      flow.flow_session = flow_session
    end
  end

  subject(:step) do
    Idv::Steps::Ipp::VerifyWaitStepShow.new(flow)
  end

  describe '#call' do
    it 'moves to the next page' do
      step.call

      expect(flow.flow_session['Idv::Steps::Ipp::VerifyWaitStep']).to eq true
    end

    it 'adds costs' do
      step.call

      expect(SpCost.where(issuer: issuer).map(&:cost_type)).to contain_exactly(
        'lexis_nexis_resolution',
      )
    end

    context 'when there is no document capture session ID' do
      let(:flow_session) do
        {
          'Idv::Steps::Ipp::VerifyStep' => true,
          pii_from_user: pii,
        }
      end

      it 'returns to the verify page' do
        expect(flow.flow_session['Idv::Steps::Ipp::VerifyStep']).to eq true
        step.call

        expect(flow.flow_session['Idv::Steps::Ipp::VerifyStep']).to eq nil
      end
    end

    context 'when there is no document capture session' do
      let(:dcs_uuid) { SecureRandom.uuid }
      let(:document_capture_session) { nil }

      it 'deletes the document capture session and returns to the verify page' do
        expect(flow.flow_session['Idv::Steps::Ipp::VerifyStep']).to eq true
        step.call

        expect(flow.flow_session['Idv::Steps::Ipp::VerifyStep']).to eq nil
        expect(flow.flow_session[:idv_verify_step_document_capture_session_uuid]).to eq nil
      end
    end

    context 'when the proofing session result is missing' do
      let(:document_capture_session) { DocumentCaptureSession.create!(user: user) }
      it 'deletes the document capture session and returns to the verify page' do
        expect(flow.flow_session['Idv::Steps::Ipp::VerifyStep']).to eq true
        step.call

        expect(flow.flow_session['Idv::Steps::Ipp::VerifyStep']).to eq nil
        expect(flow.flow_session[:idv_verify_step_document_capture_session_uuid]).to eq nil
      end
    end
  end
end
