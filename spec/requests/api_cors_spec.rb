require 'rails_helper'

RSpec.describe 'CORS headers for OpenID Connect endpoints' do
  shared_examples_for 'static API with correct CORS headers' do
    context 'origin is www.login.gov' do
      let(:http_origin) { 'https://www.login.gov' }

      it 'allows origin' do
        aggregate_failures do
          expect(response['Access-Control-Allow-Origin']).to eq(http_origin)
          expect(response['Access-Control-Allow-Methods']).to eq('GET')
        end
      end
    end

    context 'origin is login.gov' do
      let(:http_origin) { 'https://login.gov' }

      it 'allows origin' do
        aggregate_failures do
          expect(response['Access-Control-Allow-Origin']).to eq(http_origin)
          expect(response['Access-Control-Allow-Methods']).to eq('GET')
        end
      end
    end

    context 'origin is handbook.login.gov' do
      let(:http_origin) { 'https://handbook.login.gov' }

      it 'allows origin' do
        aggregate_failures do
          expect(response['Access-Control-Allow-Origin']).to eq(http_origin)
          expect(response['Access-Control-Allow-Methods']).to eq('GET')
        end
      end
    end

    context 'origin is legacy federalist preview domain' do
      let(:http_origin) { 'https://federalist-abcdef.pages.cloud.gov' }

      it 'allows origin' do
        aggregate_failures do
          expect(response['Access-Control-Allow-Origin']).to eq(http_origin)
          expect(response['Access-Control-Allow-Methods']).to eq('GET')
        end
      end
    end

    context 'origin is federalist preview' do
      let(:http_origin) { 'https://federalist-abcdef.sites.pages.cloud.gov' }

      it 'allows origin' do
        aggregate_failures do
          expect(response['Access-Control-Allow-Origin']).to eq(http_origin)
          expect(response['Access-Control-Allow-Methods']).to eq('GET')
        end
      end
    end

    context 'origin is local in development' do
      let(:http_origin) { 'http://127.0.0.1:4000' }

      it 'allows origin' do
        aggregate_failures do
          expect(response['Access-Control-Allow-Origin']).to eq(http_origin)
          expect(response['Access-Control-Allow-Methods']).to eq('GET')
        end
      end
    end

    context 'origin is not allowed' do
      let(:http_origin) { 'https://foo.com' }

      it 'does not allow origin' do
        aggregate_failures do
          expect(response).to be_ok
          expect(response['Access-Control-Allow-Origin']).to be_nil
        end
      end
    end

    context 'origin includes but is not login.gov' do
      let(:http_origin) { 'https://login.gov.evil.com' }

      it 'does not allow origin' do
        aggregate_failures do
          expect(response).to be_ok
          expect(response['Access-Control-Allow-Origin']).to be_nil
        end
      end
    end
  end

  describe '/api/country-support' do
    before do
      get api_country_support_path, headers: { 'HTTP_ORIGIN' => http_origin }
    end

    it_behaves_like 'static API with correct CORS headers'
  end

  describe '/api/analytics-events' do
    before do
      Tempfile.create do |json_file|
        json_file.rewind
        json_file << '{}'
        json_file.close

        stub_const('AnalyticsEventsController::JSON_FILE', json_file.path)

        get api_analytics_events_path, headers: { 'HTTP_ORIGIN' => http_origin }
      end
    end

    it_behaves_like 'static API with correct CORS headers'
  end
end
