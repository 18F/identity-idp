require 'rails_helper'

RSpec.describe DocAuth::Dos::Responses::HealthCheckSuccess do
  subject(:health_check_result) { described_class.new(faraday_result) }

  let(:faraday_result) do
    Faraday.get(health_check_endpoint)
  end

  let(:health_check_endpoint) do
    IdentityConfig.store.passports_api_health_check_endpoint
  end

  context 'when initialized from a successful request' do
    let(:body) do
      {
        name: 'Passport Match Process API',
        status: 'Up',
        environment: 'dev-share',
        comments: 'Ok',
      }.to_json
    end

    before do
      stub_request(:get, health_check_endpoint).to_return(body:)
    end

    it 'is successful' do
      expect(health_check_result).to be_success
    end

    it 'has the body in the extra event parameters' do
      expect(health_check_result.extra[:body]).to eq(body)
    end
  end

  # should not happen, because the connection options in
  # HealthCheckRequest prevent it, but let's stay sane if it does.
  # 403 is an arbitrary choice.
  context 'when initialized from an HTTP error response' do
    context 'with no body' do
      before do
        stub_request(:get, health_check_endpoint).to_return(status: 403)
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
        stub_request(:get, health_check_endpoint).to_return(status: 403, body: 'a 403 body')
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
