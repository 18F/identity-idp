require 'rails_helper'

RSpec.describe PassportsApi::HealthCheck do
  subject(:health_check) { described_class.new }

  let(:health_check_endpoint) do
    IdentityConfig.store.passports_api_health_check_endpoint
  end

  describe '#fetch' do
    before do
      stub_request(:get, health_check_endpoint)

      subject.fetch
    end

    it 'hits the endpoint' do
      expect(WebMock).to have_requested(:get, health_check_endpoint)
    end
  end
end
