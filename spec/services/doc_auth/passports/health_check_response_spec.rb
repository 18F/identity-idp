require 'rails_helper'

RSpec.describe DocAuth::Passports::HealthCheckResponse do
  subject(:health_check_result) { described_class.new(faraday_result) }

  let(:health_check_endpoint) do
    IdentityConfig.store.passports_api_health_check_endpoint
  end

  describe '#success?' do
    context 'happy path' do
      let(:faraday_result) do
        stub_request(:get, health_check_endpoint)
        Faraday.get(health_check_endpoint)
      end

      it 'succeeds' do
        expect(health_check_result).to be_success
      end
    end

    context 'when there is a Faraday error' do
      let(:faraday_result) { Faraday::Error.new }

      it 'does not succeed' do
        expect(health_check_result).not_to be_success
      end
    end
  end
end
