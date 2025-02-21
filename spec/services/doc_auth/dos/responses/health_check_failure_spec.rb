require 'rails_helper'

RSpec.describe DocAuth::Dos::Responses::HealthCheckFailure do
  subject(:health_check_result) { described_class.new(faraday_error:) }

  let(:health_check_endpoint) { 'https://dos-passport-healthcheck-endpoint.test.org' }

  before do
    allow(IdentityConfig.store).to(
      receive(:dos_passport_health_check_endpoint)
        .and_return(health_check_endpoint)
    )
  end

  def make_faraday_error(status:)
    stub_request(:get, health_check_endpoint).to_return(status:)

    begin
      Faraday.get(health_check_endpoint)
    rescue FaradayError => faraday_error
      faraday_error
    end
  end

  [403, 404, 500].each do |http_status|
    context "when initialized from an HTTP #{http_status} error" do
      let(:faraday_error) { make_faraday_error(status: http_status) }

      it 'is not successful' do
        expect(health_check_result).not_to be_success
      end

      it 'has the correct errors hash' do
        expect(health_check_result.errors).to eq({ network: http_status })
      end

      it 'has the faraday exception' do
        expect(health_check_result.exception).to eq(faraday_error)
      end
    end
  end
end
