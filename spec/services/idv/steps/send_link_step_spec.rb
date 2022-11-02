require 'rails_helper'

describe Idv::Steps::SendLinkStep do
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

  let(:params) do
    ActionController::Parameters.new(
      {
        doc_auth: { phone: '(201) 555-1212' },
      },
    )
  end

  let(:controller) do
    instance_double(
      'controller',
      session: { sp: { issuer: service_provider.issuer } },
      params: params,
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
      first_name: 'bob',
    }
  end

  let(:flow) do
    Idv::Flows::DocAuthFlow.new(controller, {}, 'idv/doc_auth').tap do |flow|
      flow.flow_session = { pii_from_doc: pii_from_doc }
    end
  end

  let(:irs_attempts_api_tracker) do
    IrsAttemptsApiTrackingHelper::FakeAttemptsTracker.new
  end

  subject(:step) do
    Idv::Steps::SendLinkStep.new(flow)
  end

  describe 'the return value from #call' do
    let(:response) { step.call }

    before do
      allow(controller).to receive(:irs_attempts_api_tracker).
        and_return(irs_attempts_api_tracker)
    end

    it 'includes the telephony response' do
      expect(response.extra[:telephony_response]).to eq(
        {
          errors: {},
          message_id: 'fake-message-id',
          request_id: 'fake-message-request-id',
          success: true,
        },
      )
    end
  end
end
