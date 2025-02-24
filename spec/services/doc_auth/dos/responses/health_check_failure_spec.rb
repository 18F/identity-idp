require 'rails_helper'

RSpec.describe DocAuth::Dos::Responses::HealthCheckFailure do
  include PassportApiHelpers

  subject(:health_check_result) { described_class.new(faraday_error:) }

  def make_faraday_error(status:)
    stub_request(:get, general_health_check_endpoint).to_return(status:)

    Faraday::Connection.new(url: general_health_check_endpoint) do |config|
      config.response :raise_error
    end.get
  rescue Faraday::Error => faraday_error
    faraday_error
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
        expect(health_check_result.exception).to eq(faraday_error.inspect)
      end
    end
  end
end
