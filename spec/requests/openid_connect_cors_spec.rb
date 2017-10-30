require 'rails_helper'

RSpec.describe 'CORS headers for OpenID Connect endpoints' do
  describe 'configuration endpoint' do
    context 'origin is included in ServiceProvider redirect_uris' do
      it 'allows origin' do
        get openid_connect_configuration_path, headers: { 'HTTP_ORIGIN' => 'https://example.com' }

        aggregate_failures do
          expect(response['Access-Control-Allow-Origin']).to eq('https://example.com')
          expect(response['Access-Control-Allow-Methods']).to eq('GET')
        end
      end
    end

    context 'origin is not included in ServiceProvider redirect_uris' do
      it 'does not allow origin' do
        get openid_connect_configuration_path, headers: { 'HTTP_ORIGIN' => 'https://foo.com' }

        aggregate_failures do
          expect(response).to be_ok
          expect(response['Access-Control-Allow-Origin']).to be_nil
        end
      end
    end

    context 'with a bad URI in the database' do
      before { create(:service_provider, redirect_uris: %w[/foobar]) }

      it 'does not blow up' do
        get api_openid_connect_certs_path, headers: { 'HTTP_ORIGIN' => 'https://example.com' }

        expect(response).to be_ok
      end
    end

    context 'with an invalid URI in the database' do
      before { create(:service_provider, redirect_uris: [' https://foo.com']) }

      it 'does not blow up' do
        get api_openid_connect_certs_path, headers: { 'HTTP_ORIGIN' => 'https://example.com' }

        expect(response).to be_ok
      end
    end
  end

  describe 'certs endpoint' do
    context 'origin is included in ServiceProvider redirect_uris' do
      it 'allows origin' do
        get api_openid_connect_certs_path, headers: { 'HTTP_ORIGIN' => 'https://example.com' }

        aggregate_failures do
          expect(response).to be_ok
          expect(response['Access-Control-Allow-Origin']).to eq('https://example.com')
          expect(response['Access-Control-Allow-Methods']).to eq('GET')
        end
      end
    end

    context 'origin is not included in ServiceProvider redirect_uris' do
      it 'does not allow origin' do
        get api_openid_connect_certs_path, headers: { 'HTTP_ORIGIN' => 'https://foo.com' }

        aggregate_failures do
          expect(response).to be_ok
          expect(response['Access-Control-Allow-Origin']).to be_nil
        end
      end
    end
  end

  describe 'token endpoint' do
    context 'origin is included in ServiceProvider redirect_uris' do
      it 'responds to POST requests with the right CORS headers' do
        post api_openid_connect_token_path, headers: { 'HTTP_ORIGIN' => 'https://example.com' }

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
          expect(response.body).to be_empty
          expect(response['Access-Control-Allow-Credentials']).to eq('true')
          expect(response['Access-Control-Allow-Methods']).to eq('POST, OPTIONS')
          expect(response['Access-Control-Allow-Origin']).to eq('https://example.com')
        end
      end
    end

    context 'origin is not included in ServiceProvider redirect_uris' do
      it 'does not allow POST requests from origin' do
        post api_openid_connect_token_path, headers: { 'HTTP_ORIGIN' => 'https://foo.com' }

        aggregate_failures do
          expect(response['Access-Control-Allow-Origin']).to be_nil
          expect(response['Access-Control-Allow-Methods']).to be_nil
        end
      end

      it 'does not allow OPTIONS requests from origin' do
        process(
          :options,
          api_openid_connect_token_path,
          params: {},
          headers: { 'HTTP_ORIGIN' => 'https://foo.com' }
        )

        aggregate_failures do
          expect(response['Access-Control-Allow-Origin']).to be_nil
          expect(response['Access-Control-Allow-Methods']).to be_nil
        end
      end
    end
  end

  describe 'userinfo endpoint' do
    context 'origin is included in ServiceProvider redirect_uris' do
      it 'responds to request from origin' do
        get api_openid_connect_userinfo_path, headers: { 'HTTP_ORIGIN' => 'https://example.com' }

        aggregate_failures do
          expect(response).to_not be_not_found
          expect(response['Access-Control-Allow-Origin']).to eq('https://example.com')
          expect(response['Access-Control-Allow-Methods']).to eq('GET')
        end
      end
    end

    context 'origin is not included in ServiceProvider redirect_uris' do
      it 'does not respond to request from origin' do
        get api_openid_connect_userinfo_path, headers: { 'HTTP_ORIGIN' => 'https://foo.com' }

        aggregate_failures do
          expect(response['Access-Control-Allow-Origin']).to be_nil
          expect(response['Access-Control-Allow-Methods']).to be_nil
        end
      end
    end
  end

  describe 'nil redirect_uris' do
    it 'handles a nil value gracefully' do
      ServiceProvider.create(issuer: 'foo', redirect_uris: nil)

      post api_openid_connect_token_path, headers: { 'HTTP_ORIGIN' => 'https://example.com' }

      aggregate_failures do
        expect(response).to_not be_not_found
        expect(response['Access-Control-Allow-Credentials']).to eq('true')
        expect(response['Access-Control-Allow-Methods']).to eq('POST, OPTIONS')
        expect(response['Access-Control-Allow-Origin']).to eq('https://example.com')
      end
    end
  end
end
