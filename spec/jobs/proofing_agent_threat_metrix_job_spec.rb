# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProofingAgentThreatMetrixJob, type: :job do
  let(:user) { create(:user, :fully_registered) }
  let(:request_ip) { Faker::Internet.ip_v4_address }
  let(:current_sp) { create(:service_provider) }
  let(:threatmetrix_session_id) { SecureRandom.uuid }
  let(:device_fingerprint) { SecureRandom.hex(32) }
  let(:proofing_device_profiling) { :enabled }
  let(:proofing_agent_device_profiling) { :collect_only }
  let(:lexisnexis_threatmetrix_mock_enabled) { false }
  let(:threatmetrix_response) { LexisNexisFixtures.threatmetrix_success_response_json }
  let(:threatmetrix_stub) { stub_threatmetrix_request(threatmetrix_response) }
  let(:attempts_api_tracker) { AttemptsApiTrackingHelper::FakeAttemptsTracker.new }
  let(:job_analytics) { FakeAnalytics.new }
  let(:applicant_pii) do
    {
      ssn: '123456789',
      dob: '1990-01-01',
    }
  end

  before do
    allow(attempts_api_tracker).to receive(:idv_device_risk_assessment)
    allow(AttemptsApi::Tracker).to receive(:new).and_return(attempts_api_tracker)
    allow(IdentityConfig.store).to receive_messages(
      {
        attempts_api_enabled: true,
        lexisnexis_threatmetrix_mock_enabled:,
        proofing_device_profiling:,
        proofing_agent_device_profiling:,
        lexisnexis_threatmetrix_base_url: 'https://www.example.com',
      },
    )
    allow(instance).to receive(:analytics).and_return(job_analytics)
  end

  describe '#perform' do
    let(:instance) { ProofingAgentThreatMetrixJob.new }

    subject(:perform) do
      instance.perform(
        user_id: user.id,
        applicant_pii:,
        request_ip:,
        threatmetrix_session_id:,
        current_sp:,
        timer: JobHelpers::Timer.new,
        workflow: :proofing_agent,
      )
    end

    context 'Threat Metrix Proofing Agent analysis passes' do
      let(:threatmetrix_response) do
        JSON.parse(LexisNexisFixtures.threatmetrix_success_response_json).merge!(
          'fuzzy_device_id' => device_fingerprint,
        ).to_json
      end
      let(:proofing_agent_device_profiling) { :enabled }

      it 'logs a successful result' do
        threatmetrix_stub

        perform

        expect(job_analytics).to have_logged_event(
          :idv_proofing_agent_tmx_result,
          hash_including(
            success: true,
            review_status: 'pass',
          ),
        )

        expect(attempts_api_tracker).to have_received(:idv_device_risk_assessment).with(
          success: true,
          device_fingerprint:,
          failure_reason: nil,
        )
      end

      it 'creates a DeviceProfilingResult' do
        threatmetrix_stub

        perform
        result = DeviceProfilingResult.find_by(
          user_id: user.id,
          profiling_type: DeviceProfilingResult::PROFILING_TYPES[:proofing_agent],
        )
        expect(result).to be_truthy
        expect(result.user_id).to eq(user.id)
      end
    end

    context 'with an error response result' do
      let(:reason_codes) { ['Fraud risk assessment has failed'] }
      let(:threatmetrix_response) do
        JSON.parse(LexisNexisFixtures.threatmetrix_failure_response_json).merge!(
          'fuzzy_device_id' => device_fingerprint,
          'tmx_summary_reason_code' => reason_codes,
        ).to_json
      end

      it 'stores an unsuccessful result' do
        threatmetrix_stub

        perform

        expect(job_analytics).to have_logged_event(
          :idv_proofing_agent_tmx_result,
          hash_including(
            success: false,
            review_status: 'reject',
          ),
        )

        expect(attempts_api_tracker).to have_received(:idv_device_risk_assessment).with(
          success: false,
          device_fingerprint:,
          failure_reason: { fraud_risk_summary_reason_code: reason_codes },
        )
      end
    end

    context 'with threatmetrix disabled' do
      let(:proofing_agent_device_profiling) { :disabled }

      it 'does not make a request to threatmetrix' do
        threatmetrix_stub

        perform

        expect(threatmetrix_stub).to_not have_been_requested
        expect(job_analytics).to have_logged_event(
          :idv_proofing_agent_tmx_result,
          hash_including(
            success: true,
            client: 'tmx_disabled',
            review_status: 'pass',
          ),
        )

        expect(attempts_api_tracker).to_not have_received(:idv_device_risk_assessment)
      end
    end

    context 'without a threatmetrix session ID' do
      let(:threatmetrix_session_id) { nil }
      let(:ipp_enrollment_in_progress) { false }
      let(:threatmetrix_response) { LexisNexisFixtures.threatmetrix_failure_response_json }

      it 'does not make a request to threatmetrix' do
        threatmetrix_stub

        perform

        expect(threatmetrix_stub).to_not have_been_requested
        expect(job_analytics).to have_logged_event(
          :idv_proofing_agent_tmx_result,
          hash_including(
            success: false,
            client: 'tmx_session_id_missing',
            review_status: 'reject',
          ),
        )
      end
    end
  end

  def stub_threatmetrix_request(threatmetrix_response)
    stub_request(
      :post,
      'https://www.example.com/api/session-query',
    ).to_return(body: threatmetrix_response)
  end
end
