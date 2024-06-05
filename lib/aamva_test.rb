# frozen_string_literal: true

# Helper that checks connectivity with AAMVA
class AamvaTest
  def test_connectivity
    build_proofer.proof(applicant_jonny_proofs)
  end

  def test_cert(auth_url:, verification_url:)
    proofer = build_proofer
    proofer.config.cert_enabled = true
    proofer.config.auth_url = auth_url
    proofer.config.verification_url = verification_url

    with_cleared_auth_token_cache do
      proofer.proof(applicant_jonny_proofs)
    end
  end

  private

  # Fake user in a real AAMVA state
  def applicant_jonny_proofs
    {
      uuid: '123abc',
      first_name: 'Jonny',
      last_name: 'Proofs',
      dob: '2023-01-01',
      state_id_number: '1234567890',
      state_id_jurisdiction: 'VA',
      state_id_type: 'drivers_license',
      address1: '123 Fake St',
      city: 'Arlington',
      state: 'VA',
      zipcode: '21000',
    }
  end

  def with_cleared_auth_token_cache
    Rails.cache.delete(Proofing::Aamva::AuthenticationClient::AUTH_TOKEN_CACHE_KEY)

    yield
  ensure
    Rails.cache.delete(Proofing::Aamva::AuthenticationClient::AUTH_TOKEN_CACHE_KEY)
  end

  def build_proofer
    Proofing::Aamva::Proofer.new(
      auth_request_timeout: IdentityConfig.store.aamva_auth_request_timeout,
      auth_url: IdentityConfig.store.aamva_auth_url,
      cert_enabled: IdentityConfig.store.aamva_cert_enabled,
      private_key: IdentityConfig.store.aamva_private_key,
      public_key: IdentityConfig.store.aamva_public_key,
      verification_request_timeout: IdentityConfig.store.aamva_verification_request_timeout,
      verification_url: IdentityConfig.store.aamva_verification_url,
    )
  end
end
