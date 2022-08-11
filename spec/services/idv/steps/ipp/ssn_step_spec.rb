require 'rails_helper'

describe Idv::Steps::Ipp::SsnStep do
  let(:ssn) { Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN[:ssn] }
  let(:params) { { doc_auth: { ssn: ssn } } }
  let(:session) { { sp: { issuer: service_provider.issuer } } }
  let(:user) { build(:user) }
  let(:service_provider) { create(:service_provider) }
  let(:threatmetrix_session_id) { nil }
  let(:controller) do
    instance_double(
      'controller',
      session: session,
      params: params,
      current_user: user,
    )
  end

  let(:flow) do
    Idv::Flows::InPersonFlow.new(controller, {}, 'idv/in_person').tap do |flow|
      flow.flow_session = {
        pii_from_user: {},
        threatmetrix_session_id: threatmetrix_session_id,
      }
    end
  end

  subject(:step) do
    Idv::Steps::Ipp::SsnStep.new(flow)
  end

  describe '#call' do
    it 'merges ssn into pii session value' do
      step.call

      expect(flow.flow_session[:pii_from_user][:ssn]).to eq(ssn)
    end

    context 'with existing session applicant' do
      let(:session) { super().merge(idv: { 'applicant' => {} }) }

      it 'clears applicant' do
        step.call

        expect(session[:idv]['applicant']).to be_blank
      end
    end

    context 'with proofing device profiling collecting enabled' do
      let(:threatmetrix_session_id) { 'ABCD-1234' }

      it 'adds a session id to flow session' do
        allow(IdentityConfig.store).
          to receive(:proofing_device_profiling_collecting_enabled).
          and_return(true)
        step.call

        expect(flow.flow_session[:threatmetrix_session_id]).to eq(threatmetrix_session_id)
      end
    end
  end
end
