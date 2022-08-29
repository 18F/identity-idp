require 'rails_helper'

describe Idv::Steps::VerifyStep do
  include Rails.application.routes.url_helpers

  let(:user) { build(:user) }
  let(:service_provider) do
    create(
      :service_provider,
      issuer: 'http://sp.example.com',
      app_id: '123',
    )
  end
  let(:request) do
    double(
      'request',
      remote_ip: Faker::Internet.ip_v4_address,
      headers: { 'X-Amzn-Trace-Id' => amzn_trace_id },
    )
  end
  let(:controller) do
    instance_double(
      'controller',
      session: { sp: { issuer: service_provider.issuer } },
      current_user: user,
      analytics: FakeAnalytics.new,
      url_options: {},
      request: request,
    )
  end
  let(:amzn_trace_id) { SecureRandom.uuid }

  let(:pii_from_doc) do
    {
      ssn: '123-45-6789',
    }
  end

  let(:flow) do
    Idv::Flows::DocAuthFlow.new(controller, {}, 'idv/doc_auth').tap do |flow|
      flow.flow_session = { pii_from_doc: pii_from_doc }
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

    it 'passes the X-Amzn-Trace-Id to the proofer' do
      expect(step.send(:idv_agent)).to receive(:proof_resolution).
        with(
          kind_of(DocumentCaptureSession),
          should_proof_state_id: anything,
          trace_id: amzn_trace_id,
          threatmetrix_session_id: nil,
          user_id: user.id,
          request_ip: request.remote_ip,
        )

      step.call
    end

    context 'when pii_from_doc is not present' do
      let(:flow) do
        Idv::Flows::DocAuthFlow.new(controller, {}, 'idv/doc_auth').tap do |flow|
          flow.flow_session = { 'Idv::Steps::SsnStep' => true }
        end
      end

      it 'marks step as incomplete' do
        expect(flow.flow_session['Idv::Steps::SsnStep']).to eq true
        result = step.call
        expect(flow.flow_session['Idv::Steps::SsnStep']).to eq nil
        expect(result.success?).to eq false
      end
    end

    context 'when different users use the same SSN within the same timeframe' do
      let(:user2) { create(:user) }
      let(:flow2) do
      end
      let(:controller2) do
        instance_double(
          'controller',
          session: { sp: { issuer: service_provider.issuer } },
          current_user: user2,
          analytics: FakeAnalytics.new,
          url_options: {},
          request: request,
        )
      end

      def build_step(controller)
        flow = Idv::Flows::DocAuthFlow.new(controller, {}, 'idv/doc_auth').tap do |flow|
          flow.flow_session = { pii_from_doc: pii_from_doc }
        end

        Idv::Steps::VerifyStep.new(flow)
      end

      before do
        stub_const(
          'Throttle::THROTTLE_CONFIG',
          {
            proof_ssn: {
              max_attempts: 2,
              attempt_window: 10,
            },
          }.with_indifferent_access,
        )
      end

      def redirect(step)
        step.instance_variable_get(:@flow).instance_variable_get(:@redirect)
      end

      it 'throttles them all' do
        expect(build_step(controller).call).to be_kind_of(ApplicationJob)
        expect(build_step(controller2).call).to be_kind_of(ApplicationJob)

        step = build_step(controller)
        expect(step.call).to be_nil, 'does not enqueue a job'
        expect(redirect(step)).to eq(idv_session_errors_ssn_failure_url)

        step2 = build_step(controller2)
        expect(step2.call).to be_nil, 'does not enqueue a job'
        expect(redirect(step2)).to eq(idv_session_errors_ssn_failure_url)
      end
    end
  end
end
