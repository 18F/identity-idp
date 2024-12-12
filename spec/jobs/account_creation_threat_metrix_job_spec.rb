require 'rails_helper'

RSpec.describe AccountCreationThreatMetrixJob, type: :job do
  let(:user) { create(:user, :fully_registered) }
  let(:request_ip) { Faker::Internet.ip_v4_address }
  let(:service_provider) { create(:service_provider) }
  let(:threatmetrix_session_id) { SecureRandom.uuid }
  let(:authentication_device_profiling) { :collect_only }
  let(:lexisnexis_threatmetrix_mock_enabled) { false }
  let(:threatmetrix_response) { LexisNexisFixtures.ddp_success_response_json }
  let(:threatmetrix_stub) { stub_threatmetrix_request(threatmetrix_response) }
  let(:job_analytics) { FakeAnalytics.new }

  before do
    allow(IdentityConfig.store).to receive(:account_creation_device_profiling)
      .and_return(authentication_device_profiling)
    allow(IdentityConfig.store).to receive(:lexisnexis_threatmetrix_mock_enabled)
      .and_return(lexisnexis_threatmetrix_mock_enabled)
    allow(IdentityConfig.store).to receive(:lexisnexis_threatmetrix_base_url)
      .and_return('https://www.example.com')
    allow(instance).to receive(:analytics).and_return(job_analytics)
  end

  describe '#perform' do
    let(:instance) { AccountCreationThreatMetrixJob.new }

    subject(:perform) do
      instance.perform(
        user_id: user.id,
        threatmetrix_session_id: threatmetrix_session_id,
        request_ip: request_ip,
        uuid_prefix: service_provider.app_id,
      )
    end

    context 'Threat Metrix Account Creation analysis passes' do
      let(:threatmetrix_response) { LexisNexisFixtures.ddp_success_response_json }
      it 'logs a successful result' do
        threatmetrix_stub

        perform

        expect(job_analytics).to have_logged_event(
          :account_creation_tmx_result,
          hash_including(
            success: true,
            review_status: 'pass',
          ),
        )
      end
    end

    context 'with an error response result' do
      let(:threatmetrix_response) { LexisNexisFixtures.ddp_failure_response_json }

      it 'stores an unsuccessful result' do
        threatmetrix_stub

        perform

        expect(job_analytics).to have_logged_event(
          :account_creation_tmx_result,
          hash_including(
            success: false,
            review_status: 'reject',
          ),
        )
      end
    end

    context 'with threatmetrix disabled' do
      let(:authentication_device_profiling) { :disabled }

      it 'does not make a request to threatmetrix' do
        threatmetrix_stub

        perform

        expect(threatmetrix_stub).to_not have_been_requested
        expect(job_analytics).to have_logged_event(
          :account_creation_tmx_result,
          hash_including(
            success: true,
            client: 'tmx_disabled',
            review_status: 'pass',
          ),
        )
      end
    end

    context 'without a threatmetrix session ID' do
      let(:threatmetrix_session_id) { nil }
      let(:ipp_enrollment_in_progress) { false }
      let(:threatmetrix_response) { LexisNexisFixtures.ddp_failure_response_json }

      it 'does not make a request to threatmetrix' do
        threatmetrix_stub

        perform

        expect(threatmetrix_stub).to_not have_been_requested
        expect(job_analytics).to have_logged_event(
          :account_creation_tmx_result,
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
