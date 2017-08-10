require 'rails_helper'

RSpec.describe 'CORS headers for OpenID Connect endpoints' do
  describe 'configuration endpoint' do
    it 'sets CORS headers to allow all origins' do
      get openid_connect_configuration_path, nil, 'HTTP_ORIGIN' => 'https://example.com'

      aggregate_failures do
        expect(response['Access-Control-Allow-Origin']).to eq('https://example.com')
        expect(response['Access-Control-Allow-Methods']).to eq('GET')
      end
    end
  end

  describe 'certs endpoint' do
    it 'sets CORS headers to allow all origins' do
      get api_openid_connect_certs_path, nil, 'HTTP_ORIGIN' => 'https://example.com'

      aggregate_failures do
        expect(response).to be_ok
        expect(response['Access-Control-Allow-Origin']).to eq('https://example.com')
        expect(response['Access-Control-Allow-Methods']).to eq('GET')
      end
    end
  end

  describe 'token endpoint' do
    it 'responds to POST requests with the right CORS headers' do
      post api_openid_connect_token_path, nil, 'HTTP_ORIGIN' => 'https://example.com'

      aggregate_failures do
        expect(response).to_not be_not_found
        expect(response['Access-Control-Allow-Credentials']).to eq('true')
        expect(response['Access-Control-Allow-Methods']).to eq('POST, OPTIONS')
        expect(response['Access-Control-Allow-Origin']).to eq('https://example.com')
      end
    end

    it 'responds to OPTIONS requests with the right CORS headers' do
      process(
        :options,
        api_openid_connect_token_path,
        params: {},
        headers: { 'HTTP_ORIGIN' => 'https://example.com' }
      )

      aggregate_failures do
        expect(response).to be_ok
        expect(response['Access-Control-Allow-Credentials']).to eq('true')
        expect(response['Access-Control-Allow-Methods']).to eq('POST, OPTIONS')
        expect(response['Access-Control-Allow-Origin']).to eq('https://example.com')
      end
    end
  end

  describe 'userinfo endpoint' do
    it 'sets CORS headers to allow all origins' do
      get api_openid_connect_userinfo_path, nil, 'HTTP_ORIGIN' => 'https://example.com'

      aggregate_failures do
        expect(response).to_not be_not_found
        expect(response['Access-Control-Allow-Origin']).to eq('https://example.com')
        expect(response['Access-Control-Allow-Methods']).to eq('GET')
      end
    end
  end
end
