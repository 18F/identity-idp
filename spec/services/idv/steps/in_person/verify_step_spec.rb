require 'rails_helper'

RSpec.describe Idv::Steps::InPerson::VerifyStep do
  include Rails.application.routes.url_helpers

  let(:user) { build(:user) }
  let(:service_provider) { create(:service_provider) }
  let(:amzn_trace_id) { SecureRandom.uuid }
  let(:request) do
    double(
      'request',
      headers: {
        'X-Amzn-Trace-Id' => amzn_trace_id,
      },
      remote_ip: Faker::Internet.ip_v4_address,
    )
  end
  let(:controller_args) do
    {
      request: request,
      session: { sp: { issuer: service_provider.issuer } },
      url_options: {},
    }
  end

  let(:controller) do
    instance_double(
      'controller',
      analytics: FakeAnalytics.new,
      irs_attempts_api_tracker: IrsAttemptsApiTrackingHelper::FakeAttemptsTracker.new,
      current_user: user,
      **controller_args,
    )
  end

  let(:pii) do
    Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN.dup
  end

  let(:flow_args) do
    [{}, 'idv/in_person']
  end
  let(:pii_hash) { { pii_from_user: pii } }
  let(:flow) do
    Idv::Flows::InPersonFlow.new(controller, *flow_args).tap do |flow|
      flow.flow_session = pii_hash
    end
  end

  subject(:step) do
    Idv::Steps::InPerson::VerifyStep.new(flow)
  end

  describe '#call' do
    let(:same_address_as_id) { 'false' }
    let(:capture_secondary_id_enabled) { true }
    let(:enrollment) { InPersonEnrollment.new(capture_secondary_id_enabled:) }
    before do
      allow(user).to receive(:establishing_in_person_enrollment).
        and_return(enrollment)
      pii[:same_address_as_id] = same_address_as_id
    end

    it 'sets uuid_prefix on pii_from_user' do
      expect(Idv::Agent).to receive(:new).
        with(hash_including(uuid_prefix: service_provider.app_id)).and_call_original

      step.call

      expect(flow.flow_session[:pii_from_user][:uuid_prefix]).to eq service_provider.app_id
    end

    it 'passes the correct X-Amzn-Trace-Id and double_address_verification value to the proofer' do
      expect(step.send(:idv_agent)).to receive(:proof_resolution).
        with(
          kind_of(DocumentCaptureSession),
          should_proof_state_id: anything,
          trace_id: amzn_trace_id,
          threatmetrix_session_id: nil,
          user_id: anything,
          request_ip: request.remote_ip,
          double_address_verification: true,
        )

      step.call
    end

    it 'only enqueues a job once' do
      step.call
      expect(step.send(:idv_agent)).not_to receive(:proof_resolution)

      step.call
    end

    context 'when pii_from_user is blank' do
      let(:idv_in_person_step) { 'Idv::Steps::InPerson::SsnStep' }
      let(:flow) do
        Idv::Flows::InPersonFlow.new(controller, *flow_args).tap do |flow|
          flow.flow_session = { idv_in_person_step => true, pii_from_user: {} }
        end
      end

      it 'marks step as incomplete' do
        expect(flow.flow_session[idv_in_person_step]).to eq true
        result = step.call
        expect(flow.flow_session[idv_in_person_step]).to eq nil
        expect(result.success?).to eq false
      end
    end

    context 'when different users use the same SSN within the same timeframe' do
      let(:user2) { create(:user) }
      let(:controller2) do
        instance_double(
          'controller',
          analytics: FakeAnalytics.new,
          irs_attempts_api_tracker: IrsAttemptsApiTrackingHelper::FakeAttemptsTracker.new,
          current_user: user2,
          **controller_args,
        )
      end

      def build_step(controller_instance)
        flow = Idv::Flows::InPersonFlow.new(controller_instance, *flow_args).tap do |flow|
          flow.flow_session = { **pii_hash }
        end

        Idv::Steps::InPerson::VerifyStep.new(flow)
      end

      before do
        allow(IdentityConfig.store).to receive(:proof_ssn_max_attempts).and_return(3)
        allow(IdentityConfig.store).to receive(:proof_ssn_max_attempt_window_in_minutes).
          and_return(10)
      end

      def redirect(step_instance)
        step_instance.instance_variable_get(:@flow).instance_variable_get(:@redirect)
      end

      it 'throttles them all' do
        expect(build_step(controller).call).to be_kind_of(ApplicationJob)
        expect(build_step(controller2).call).to be_kind_of(ApplicationJob)

        user1_step = build_step(controller)
        expect(user1_step.call).to be_nil, 'does not enqueue a job'
        expect(redirect(user1_step)).to eq(idv_session_errors_ssn_failure_url)

        user2_step = build_step(controller2)
        expect(user2_step.call).to be_nil, 'does not enqueue a job'
        expect(redirect(user2_step)).to eq(idv_session_errors_ssn_failure_url)
      end
    end
  end
end
