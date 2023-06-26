require 'rails_helper'

RSpec.describe IrsAttemptsApi::Tracker do
  before do
    allow(IdentityConfig.store).to receive(:irs_attempt_api_enabled).
      and_return(irs_attempts_api_enabled)
    allow(request).to receive(:user_agent).and_return('example/1.0')
    allow(request).to receive(:remote_ip).and_return('192.0.2.1')
    allow(request).to receive(:headers).and_return(
      { 'CloudFront-Viewer-Address' => '192.0.2.1:1234' },
    )
  end

  let(:irs_attempts_api_enabled) { true }
  let(:session_id) { 'test-session-id' }
  let(:enabled_for_session) { true }
  let(:request) { instance_double(ActionDispatch::Request) }
  let(:service_provider) { create(:service_provider) }
  let(:cookie_device_uuid) { 'device_id' }
  let(:sp_request_uri) { 'https://example.com/auth_page' }
  let(:user) { create(:user) }
  let(:analytics) { FakeAnalytics.new }

  subject do
    described_class.new(
      session_id: session_id,
      request: request,
      user: user,
      sp: service_provider,
      cookie_device_uuid: cookie_device_uuid,
      sp_request_uri: sp_request_uri,
      enabled_for_session: enabled_for_session,
      analytics: analytics,
    )
  end

  describe '#parse_failure_reason' do
    let(:mock_error_message) { 'failure_reason_from_error' }
    let(:mock_error_details) { [{ mock_error: 'failure_reason_from_error_details' }] }

    it 'parses failure_reason from error_details' do
      test_failure_reason = subject.parse_failure_reason(
        { errors: mock_error_message,
          error_details: mock_error_details },
      )

      expect(test_failure_reason).to eq(mock_error_details)
    end

    it 'parses failure_reason from errors when no error_details present' do
      class MockFailureReason
        def errors
          'failure_reason_from_error'
        end

        def to_h
          {}
        end
      end

      test_failure_reason = subject.parse_failure_reason(MockFailureReason.new)

      expect(test_failure_reason).to eq(mock_error_message)
    end
  end
end
