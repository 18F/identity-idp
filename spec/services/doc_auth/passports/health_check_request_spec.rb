require 'rails_helper'

RSpec.describe DocAuth::Passports::HealthCheckRequest do
  subject(:health_check_request) { described_class.new(analytics:) }

  let(:analytics) { FakeAnalytics.new }

  let(:health_check_endpoint) do
    IdentityConfig.store.passports_api_health_check_endpoint
  end

  describe '#fetch' do
    let(:result) { health_check_request.fetch }

    context 'happy path' do
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

      describe 'the #fetch result' do
        it 'succeeds' do
          expect(result).to be_success
        end
      end
    end

    context 'when Faraday raises an error' do
      before do
        stub_request(:get, health_check_endpoint).to_raise(Faraday::Error)
        result
      end

      it 'hits the endpoint' do
        expect(WebMock).to have_requested(:get, health_check_endpoint)
      end

      it 'logs the request' do
        expect(analytics).to have_logged_event(:passport_api_health_check)
      end

      describe 'the #fetch result' do
        it 'does not succeed' do
          expect(result).not_to be_success
        end
      end
    end

    context 'when Faraday returns an HTTP error' do
      before do
        stub_request(:get, health_check_endpoint).to_return(status: 500)
        result
      end

      it 'hits the endpoint' do
        expect(WebMock).to have_requested(:get, health_check_endpoint)
      end

      it 'logs the request' do
        expect(analytics).to have_logged_event(:passport_api_health_check)
      end

      describe 'the #fetch result' do
        it 'does not succeed' do
          expect(result).not_to be_success
        end
      end
    end
  end
end
