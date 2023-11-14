require 'rails_helper'

RSpec.describe 'AAMVA cert script' do
  before do
    allow(IdentityConfig.store).to receive(:proofer_mock_fallback).and_return(false)
    allow(IdentityConfig.store).to receive(:aamva_private_key).
      and_return(Base64.strict_encode64(AamvaFixtures.aamva_private_key.to_der))
    allow(IdentityConfig.store).to receive(:aamva_public_key).
      and_return(Base64.strict_encode64(AamvaFixtures.aamva_public_key.to_der))
  end

  # This script can be run against the DLDV test environment (with the correct URLs)
  subject(:run_script) do
    proofer = Proofing::Resolution::ProgressiveProofer.new.send(:state_id_proofer)
    proofer.config.cert_enabled = true
    proofer.config.auth_url = 'https://example.com/a'
    proofer.config.verification_url = 'https://example.com:18449/b'

    Rails.cache.delete(Proofing::Aamva::AuthenticationClient::AUTH_TOKEN_CACHE_KEY)

    applicant = {
     'state_id_number' => 'DLDVSTRUCTUREDTEST12', # fake info that came from them
     'state_id_jurisdiction' => 'VA',
     'state_id_type' => 'drivers_license',
     'uuid' => 'test'
    }

    proofer.proof(applicant)
  end

  after do
    Rails.cache.delete(Proofing::Aamva::AuthenticationClient::AUTH_TOKEN_CACHE_KEY)
  end

  it 'provides a sample script that can be run to test AAMVA' do
    stub_request(:post, 'https://example.com/a').
      with(body: %r{http://schemas.xmlsoap.org/ws/2005/02/trust/RST/SCT}).
      to_return(body: AamvaFixtures.security_token_response, status: 200)
    stub_request(:post, 'https://example.com/a').
      with(body: %r{http://aamva.org/authentication/3.1.0/IAuthenticationService/Authenticate}).
      to_return(body: AamvaFixtures.authentication_token_response, status: 200)
    stub_request(:post, 'https://example.com:18449/b').
      to_return(body: AamvaFixtures.verification_response_namespaced_success)

    result = run_script
    expect(result.exception).to be_nil

    expect(WebMock).to(
      have_requested(:post, 'https://example.com:18449/b').with do |req|
        expect(Nokogiri::XML(req.body).at_xpath('//ns1:MessageDestinationId').text).
          to eq('P6'), 'it sends a request with the designated fake state'
      end,
    )
  end
end
