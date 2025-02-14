require 'rails_helper'

RSpec.describe DocAuth::Passports::HealthCheckResponse do
  subject(:health_check_result) { described_class.new(faraday_result) }

  let(:faraday_result) do
    begin
      Faraday.get(health_check_endpoint)
    rescue Faraday::Error => error
      error
    end
  end

  let(:health_check_endpoint) do
    IdentityConfig.store.passports_api_health_check_endpoint
  end

  context 'when initialized from a Faraday::Response' do
    before { stub_request(:get, health_check_endpoint) }

    it 'is successful' do
      expect(health_check_result).to be_success
    end
  end

  context 'when initialized from a Faraday::Error' do
    before { stub_request(:get, health_check_endpoint).to_raise(Faraday::Error) }
        
    it 'is not successful' do
      expect(health_check_result).not_to be_success
    end
  end
end
