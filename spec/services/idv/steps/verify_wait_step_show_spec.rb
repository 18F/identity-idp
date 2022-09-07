require 'rails_helper'

describe Idv::Steps::VerifyWaitStepShow do
  include Rails.application.routes.url_helpers

  let(:user) { build(:user) }
  let(:issuer) { 'test_issuer' }
  let(:service_provider) { build(:service_provider, issuer: issuer) }
  let(:resolution_transaction_id) { Proofing::Mock::ResolutionMockClient::TRANSACTION_ID }
  let(:threatmetrix_transaction_id) { Proofing::Mock::DdpMockClient::TRANSACTION_ID }

  let(:request) { FakeRequest.new }

  let(:controller) do
    instance_double(
      'controller',
      analytics: FakeAnalytics.new,
      irs_attempts_api_tracker: IrsAttemptsApiTrackingHelper::FakeAttemptsTracker.new,
      current_sp: service_provider,
      current_user: user,
      flash: {},
      poll_with_meta_refresh: nil,
      url_options: {},
      request: request,
    )
  end

  let(:idv_result) do
    {
      context: { stages: { resolution: { transaction_id: resolution_transaction_id },
                           threatmetrix: { transaction_id: threatmetrix_transaction_id } } },
      errors: {},
      exception: nil,
      success: true,
    }
  end

  let(:document_capture_session) do
    document_capture_session = DocumentCaptureSession.create!(user: user)
    document_capture_session.create_proofing_session
    document_capture_session.store_proofing_result(idv_result)
    document_capture_session
  end

  let(:dcs_uuid) { document_capture_session.uuid }

  let(:pii) do
    Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN.dup
  end

  let(:flow_session) do
    {
      idv_verify_step_document_capture_session_uuid: dcs_uuid,
      'Idv::Steps::VerifyStep' => true,
      pii_from_doc: pii,
    }
  end

  let(:flow) do
    Idv::Flows::DocAuthFlow.new(controller, {}, 'idv/doc_auth').tap do |flow|
      flow.flow_session = flow_session
    end
  end

  subject(:step) do
    Idv::Steps::VerifyWaitStepShow.new(flow)
  end

  describe '#call' do
    it 'moves to the next page' do
      expect(flow.flow_session['Idv::Steps::VerifyWaitStep']).to be_nil
      step.call

      expect(flow.flow_session['Idv::Steps::VerifyWaitStep']).to be true
    end

    it 'adds costs' do
      allow(IdentityConfig.store).to receive(:proofing_device_profiling_collecting_enabled).
        and_return(true)
      allow(IdentityConfig.store).to receive(:lexisnexis_threatmetrix_enabled).and_return(true)

      step.call

      sp_costs = SpCost.where(issuer: issuer, cost_type: 'lexis_nexis_resolution')
      expect(sp_costs[0].transaction_id).to eq(resolution_transaction_id)
      sp_costs = SpCost.where(issuer: issuer, cost_type: 'threatmetrix')
      expect(sp_costs[0].transaction_id).to eq(threatmetrix_transaction_id)

      proofing_cost = ProofingCost.last
      expect(proofing_cost.user_id).to eq(user.id)
      expect(proofing_cost.threatmetrix_count).to eq(1)
      expect(proofing_cost.lexis_nexis_resolution_count).to eq(1)
    end

    it 'clears pii from session' do
      step.call

      expect(flow_session[:pii_from_doc]).to be_blank
    end

    context 'when there is no document capture session ID' do
      let(:flow_session) do
        {
          'Idv::Steps::VerifyStep' => true,
          pii_from_doc: pii,
        }
      end

      it 'returns to the verify page' do
        expect(flow.flow_session['Idv::Steps::VerifyStep']).to be true
        step.call

        expect(flow.flow_session['Idv::Steps::VerifyStep']).to be_nil
      end
    end

    context 'when there is no document capture session' do
      let(:dcs_uuid) { SecureRandom.uuid }
      let(:document_capture_session) { nil }

      it 'deletes the document capture session and returns to the verify page' do
        expect(flow.flow_session['Idv::Steps::VerifyStep']).to be true
        step.call

        expect(flow.flow_session['Idv::Steps::VerifyStep']).to be_nil
        expect(flow.flow_session[:idv_verify_step_document_capture_session_uuid]).to be_nil
      end
    end

    context 'when the proofing session result is missing' do
      let(:document_capture_session) { DocumentCaptureSession.create!(user: user) }

      it 'deletes the document capture session and returns to the verify page' do
        expect(flow.flow_session['Idv::Steps::VerifyStep']).to be true
        step.call

        expect(flow.flow_session['Idv::Steps::VerifyStep']).to be_nil
        expect(flow.flow_session[:idv_verify_step_document_capture_session_uuid]).to be_nil
      end
    end

    context 'when verification fails' do
      let(:idv_result) do
        {
          context: { stages: { resolution: {} } },
          errors: {},
          exception: nil,
          success: false,
        }
      end

      it 'marks the verify step incomplete and redirects to the warning page' do
        expect(step).to receive(:redirect_to).with(idv_session_errors_warning_url)
        expect(flow.flow_session['Idv::Steps::VerifyStep']).to be true
        step.call

        expect(flow.flow_session['Idv::Steps::VerifyStep']).to be_nil
      end
    end

    context 'when verification encounters an exception' do
      let(:idv_result) do
        {
          context: { stages: { resolution: {} } },
          errors: {},
          exception: StandardError.new('testing'),
          success: false,
        }
      end

      it 'marks the verify step incomplete and redirects to the exception page' do
        expect(step).to receive(:redirect_to).with(idv_session_errors_exception_url)
        expect(flow.flow_session['Idv::Steps::VerifyStep']).to be true
        step.call

        expect(flow.flow_session['Idv::Steps::VerifyStep']).to be_nil
      end
    end
  end
end
