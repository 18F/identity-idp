require 'rails_helper'

describe Idv::Steps::SsnStep do
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
      params: {},
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
      first_name: Faker::Name.first_name,
    }
  end

  let(:flow) do
    Idv::Flows::DocAuthFlow.new(controller, {}, 'idv/doc_auth').tap do |flow|
      flow.flow_session = { pii_from_doc: pii_from_doc }
    end
  end

  subject(:step) do
    Idv::Steps::SsnStep.new(flow)
  end

  describe '#call' do
    context 'when pii_from_doc is not present' do
      let(:flow) do
        Idv::Flows::DocAuthFlow.new(controller, {}, 'idv/doc_auth').tap do |flow|
          flow.flow_session = { 'Idv::Steps::DocumentCaptureStep' => true }
        end
      end

      it 'marks previous step as incomplete' do
        expect(flow.flow_session['Idv::Steps::DocumentCaptureStep']).to eq true
        result = step.call
        expect(flow.flow_session['Idv::Steps::DocumentCaptureStep']).to eq nil
        expect(result.success?).to eq false
      end
    end
  end
end
