module IdvVendorRequestHelper
  def stub_aamva_request(response)
    allow(IdentityConfig.store).to receive(:aamva_private_key)
      .and_return(AamvaFixtures.example_config.private_key)
    allow(IdentityConfig.store).to receive(:aamva_public_key)
      .and_return(AamvaFixtures.example_config.public_key)
    stub_request(:post, IdentityConfig.store.aamva_auth_url)
      .to_return(
        { body: AamvaFixtures.security_token_response },
        { body: AamvaFixtures.authentication_token_response },
      )
    stub_request(:post, IdentityConfig.store.aamva_verification_url)
      .to_return(body: response)
  end

  def stub_instant_verify_request(response)
    instant_verify_url = URI.join(
      IdentityConfig.store.lexisnexis_base_url,
      '/restws/identity/v2/',
      IdentityConfig.store.lexisnexis_account_id + '/',
      IdentityConfig.store.lexisnexis_instant_verify_workflow + '/',
      'conversation',
    )
    stub_request(:post, instant_verify_url).to_return(body: response)
  end
end
