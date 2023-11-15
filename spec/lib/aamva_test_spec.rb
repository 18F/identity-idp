require 'rails_helper'
require 'aamva_test'

RSpec.describe AamvaTest do
  before do
    allow(IdentityConfig.store).to receive(:proofer_mock_fallback).and_return(false)
    allow(IdentityConfig.store).to receive(:aamva_private_key).
      and_return(Base64.strict_encode64(AamvaFixtures.aamva_private_key.to_der))
    allow(IdentityConfig.store).to receive(:aamva_public_key).
      and_return(Base64.strict_encode64(AamvaFixtures.aamva_public_key.to_der))

    stub_request(:post, auth_url).
      with(body: %r{http://schemas.xmlsoap.org/ws/2005/02/trust/RST/SCT}).
      to_return(body: AamvaFixtures.security_token_response, status: 200)
    stub_request(:post, auth_url).
      with(body: %r{http://aamva.org/authentication/3.1.0/IAuthenticationService/Authenticate}).
      to_return(body: AamvaFixtures.authentication_token_response, status: 200)
    stub_request(:post, verification_url).
      to_return(body: AamvaFixtures.verification_response_namespaced_success)
  end

  subject(:tester) { AamvaTest.new }

  describe '#test_connectivity' do
    let(:auth_url) { IdentityConfig.store.aamva_auth_url }
    let(:verification_url) { IdentityConfig.store.aamva_verification_url }

    it 'connects to the live config' do
      result = tester.test_connectivity

      expect(result.exception).to be_nil
    end
  end

  describe '#test_cert' do
    let(:auth_url) { 'https://example.com/a' }
    let(:verification_url) { 'https://example.com:18449/b' }

    it 'makes a test request to the P6 jurisdisction' do
      result = tester.test_cert(auth_url:, verification_url:)

      expect(result.exception).to be_nil

      expect(WebMock).to(
        have_requested(:post, verification_url).with do |req|
          expect(Nokogiri::XML(req.body).at_xpath('//ns1:MessageDestinationId').text).
            to eq('P6'), 'it sends a request with the designated fake state'
        end,
      )
    end

    it 'clears the auth token cache after' do
      Rails.cache.write(Proofing::Aamva::AuthenticationClient::AUTH_TOKEN_CACHE_KEY, 'aaa')

      tester.test_cert(auth_url:, verification_url:)

      expect(Rails.cache.read(Proofing::Aamva::AuthenticationClient::AUTH_TOKEN_CACHE_KEY)).
        to be_nil
    end
  end
end
