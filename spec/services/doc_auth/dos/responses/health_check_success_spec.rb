require 'rails_helper'

RSpec.describe DocAuth::Dos::Responses::HealthCheckSuccess do
  include PassportApiHelpers

  subject(:health_check_result) do
    described_class.new(faraday_response:)
  end

  before do
    stub_health_check_settings
    stub_health_check_endpoints
  end

  context 'when initialized from a successful general health check response' do
    let(:faraday_response) do
      Faraday.get(general_health_check_endpoint)
    end

    it 'is successful' do
      expect(health_check_result).to be_success
    end

    it 'has the body in the extra event parameters' do
      expect(health_check_result.extra[:body]).to eq(
        successful_api_general_health_check_body.to_json,
      )
    end
  end

  context 'when initialized from a successful composite health check response' do
    let(:faraday_response) do
      Faraday.get(composite_health_check_endpoint)
    end

    it 'is successful' do
      expect(health_check_result).to be_success
    end

    it 'has the body in the extra event parameters' do
      expect(health_check_result.extra[:body]).to eq(
        successful_api_composite_health_check_body.to_json,
      )
    end
  end

  # should not happen, because the :raise_error middleware set up in
  # HealthCheckRequest#connection prevent it, but let's stay sane if
  # it does.  403 is an arbitrary choice.
  context 'when initialized from an HTTP error response' do
    let(:faraday_response) do
      Faraday.get(general_health_check_endpoint)
    end

    context 'with no body' do
      before do
        stub_request(:get, general_health_check_endpoint).to_return(status: 403)
      end

      it 'is not successful' do
        expect(health_check_result).not_to be_success
      end

      it 'does not include the body: key in the extras' do
        expect(health_check_result.extra).not_to have_key(:body)
      end
    end

    context 'with a body' do
      before do
        stub_request(:get, general_health_check_endpoint).to_return(status: 403, body: 'a 403 body')
      end

      it 'is not successful' do
        expect(health_check_result).not_to be_success
      end

      it 'includes the body in the extras' do
        expect(health_check_result.extra[:body]).to eq('a 403 body')
      end
    end
  end
end
