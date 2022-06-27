require 'rails_helper'

describe Idv::Steps::DocumentCaptureStep do
  include Rails.application.routes.url_helpers

  let(:user) { build(:user) }
  let(:service_provider) do
    create(
      :service_provider,
      issuer: 'http://sp.example.com',
      app_id: '123',
    )
  end
  let(:controller) do
    instance_double(
      'controller',
      session: { sp: { issuer: service_provider.issuer } },
      current_user: user,
      analytics: FakeAnalytics.new,
      url_options: {},
      request: double(
        'request',
        headers: {
          'X-Amzn-Trace-Id' => amzn_trace_id,
        },
      ),
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
      flow.flow_session = {}
    end
  end

  subject(:step) do
    Idv::Steps::DocumentCaptureStep.new(flow)
  end

  describe '#call' do
    it 'does not raise an exception when stored_result is nil' do
      allow(FeatureManagement).to receive(:document_capture_async_uploads_enabled?).
        and_return(false)
      allow(step).to receive(:stored_result).and_return(nil)
      step.call
    end
  end
end
