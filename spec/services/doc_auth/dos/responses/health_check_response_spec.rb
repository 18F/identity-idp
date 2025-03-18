require 'rails_helper'

RSpec.describe DocAuth::Dos::Responses::HealthCheckResponse do
  include PassportApiHelpers

  subject(:health_check_response) do
    described_class.new(faraday_response:)
  end

  def make_faraday_response(status:)
    stub_request(:get, general_health_check_endpoint).to_return(status:)

    Faraday::Connection.new(url: general_health_check_endpoint) do |config|
      config.response :raise_error
    end.get
  rescue Faraday::Error => faraday_error
    faraday_error
  end

  before do
    stub_health_check_settings
  end

  [403, 404, 500].each do |http_status|
    context "when initialized from an HTTP #{http_status} error" do
      let(:faraday_response) { make_faraday_response(status: http_status) }

      it 'is not successful' do
        expect(health_check_response).not_to be_success
      end

      it 'has the correct errors hash' do
        expect(health_check_response.errors).to eq({ network: http_status })
      end

      it 'has the faraday exception' do
        expect(health_check_response.exception).to eq(faraday_response.inspect)
      end
    end
  end

  context 'when initialized from a successful general health check response' do
    before do
      stub_health_check_endpoints
    end

    let(:faraday_response) do
      Faraday.get(general_health_check_endpoint)
    end

    it 'is successful' do
      expect(health_check_response).to be_success
    end

    it 'has the body in the extra event parameters' do
      expect(health_check_response.extra[:body]).to eq(
        successful_api_general_health_check_body.to_json,
      )
    end
  end

  context 'when initialized from a successful composite health check response' do
    before do
      stub_health_check_endpoints
    end

    let(:faraday_response) do
      Faraday.get(composite_health_check_endpoint)
    end

    it 'is successful' do
      expect(health_check_response).to be_success
    end

    it 'has the body in the extra event parameters' do
      expect(health_check_response.extra[:body]).to eq(
        successful_api_composite_health_check_body.to_json,
      )
    end
  end

  context 'when initialized from an OK response but the body says they are down' do
    let(:faraday_response) do
      Faraday.get(general_health_check_endpoint)
    end

    let(:health_check_down_body) do
      { status: 'down' }.to_json
    end

    before do
      stub_request(:get, general_health_check_endpoint).to_return(
        body: health_check_down_body,
      )
    end

    it 'is not successful' do
      expect(health_check_response).not_to be_success
    end

    it 'includes the body in the extras' do
      expect(health_check_response.extra[:body]).to eq(health_check_down_body)
    end

    context 'when composite healthheck down stream system is down' do
      let(:faraday_response) do
        Faraday.get(composite_health_check_endpoint)
      end

      let(:health_check_down_body) do
        {
          status: 'uP',
          downstreamHealth: [
            {
              status: 'up',
              downstreamHealth: nil,
            },
            {
              status: 'up',
              downstreamHealth: [],
            },
            {
              status: 'up',
              downstreamHealth: [
                {
                  status: 'up',
                  downstreamHealth: nil,
                },
                {
                  status: 'up',
                  downstreamHealth: [],
                },
                {
                  status: 'down',
                },
              ],
            },
          ],
        }.to_json
      end

      before do
        stub_request(:get, composite_health_check_endpoint)
          .to_return_json(body: health_check_down_body)
      end

      it 'is not successful' do
        expect(health_check_response).not_to be_success
      end

      it 'includes the body in the extras' do
        expect(health_check_response.extra[:body]).to eq(health_check_down_body)
      end
    end
  end
end
