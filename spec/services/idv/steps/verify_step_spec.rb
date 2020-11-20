require 'rails_helper'

describe Idv::Steps::VerifyStep do
  let(:user) { build(:user) }
  let(:service_provider) do
    create(:service_provider,
           issuer: 'http://sp.example.com',
           app_id: '123')
  end
  let(:controller) do
     instance_double('controller',
                     session: { sp: { issuer: service_provider.issuer } },
                     current_user: user,
                     request: double('request',
                                     headers: {
                                       'X-Amzn-Trace-Id' => amzn_trace_id,
                                     }))
  end
  let(:amzn_trace_id) { SecureRandom.uuid }

  let(:flow) do
    Idv::Flows::DocAuthFlow.new(controller, {}, 'idv/doc_auth').tap do |flow|
      flow.flow_session = { pii_from_doc: {} }
    end
  end

  subject(:step) do
    Idv::Steps::VerifyStep.new(flow)
  end

  describe '#call' do
    it 'sets uuid_prefix on pii_from_doc' do
      expect(Idv::Agent).to receive(:new).
        with(hash_including(uuid_prefix: service_provider.app_id)).and_call_original

      step.call

      expect(flow.flow_session[:pii_from_doc][:uuid_prefix]).to eq service_provider.app_id
    end

    it 'passes the X-Amzn-Trace-Id to the lambda' do
      expect(step.send(:idv_agent)).to receive(:proof_resolution)
        .with(kind_of(DocumentCaptureSession), should_proof_state_id: anything, trace_id: amzn_trace_id)

      step.call
    end
  end
end
