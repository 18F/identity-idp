require 'rails_helper'

RSpec.describe DocAuth::Passports::HealthCheckRequest do
  subject(:health_check) { described_class.new(analytics:) }

  let(:analytics) { FakeAnalytics.new }

  let(:health_check_endpoint) do
    IdentityConfig.store.passports_api_health_check_endpoint
  end

  describe '#fetch' do
    let(:result) { subject.fetch }

    before do
      stub_request(:get, health_check_endpoint)
      result
    end

    it 'hits the endpoint' do
      expect(WebMock).to have_requested(:get, health_check_endpoint)
    end

    it 'logs the request' do
      expect(analytics).to have_logged_event(:passport_api_health_check)
    end
  end
end
