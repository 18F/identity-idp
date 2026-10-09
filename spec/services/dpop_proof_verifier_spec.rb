require 'rails_helper'

RSpec.describe DpopProofVerifier do
  let(:url) { 'https://idp.example.gov/api/openid_connect/token' }
  let(:method) { 'POST' }
  let(:access_token) { nil }
  let(:expected_thumbprint) { nil }
  let(:proof) { build_dpop_proof(url:, method:, access_token:) }

  subject(:result) do
    described_class.new(
      proof:, http_method: method, http_url: url, access_token:, expected_thumbprint:,
    ).call
  end

  def verify(proof, **options)
    described_class.new(proof:, http_method: method, http_url: url, **options).call
  end

  it 'accepts a fresh ES256 proof for this request and returns the key thumbprint' do
    expect(result).to be_success
    expect(result.thumbprint).to eq(dpop_thumbprint)
    expect(result.error_message).to be_nil
  end

  it 'accepts an RS256 proof' do
    key = OpenSSL::PKey::RSA.new(2048)
    proof = build_dpop_proof(url:, key:, header: { alg: 'RS256' })
    result = verify(proof)
    expect(result).to be_success
    expect(result.thumbprint).to eq(dpop_thumbprint(key))
  end

  it 'ignores case, default ports, trailing slash, query and fragment when matching htu' do
    proof = build_dpop_proof(url: 'HTTPS://IDP.example.gov:443/api/openid_connect/token/?x=1#f')
    expect(verify(proof)).to be_success
  end

  it 'refuses the same jti twice' do
    expect(result).to be_success
    second = verify(proof)
    expect(second.error_type).to eq(:dpop_proof_replayed)
    expect(second.error_message).to eq(t('openid_connect.token.errors.dpop_proof_replayed'))
  end

  it 'keeps the jti for twice the acceptance window' do
    allow(IdentityConfig.store).to receive(:dpop_proof_max_age_seconds).and_return(120)
    expect(result).to be_success
    key = DpopProofVerifier::JTI_KEY_PREFIX +
          Digest::SHA256.hexdigest("#{dpop_thumbprint}\n#{JWT.decode(proof, nil, false)[0]['jti']}")
    expect(REDIS_POOL.with { |client| client.ttl(key) }).to be_between(230, 240)
  end

  context 'with a token presented alongside the proof' do
    let(:access_token) { SecureRandom.urlsafe_base64(32) }

    it 'requires ath to match the token' do
      expect(result).to be_success
      wrong = build_dpop_proof(url:, access_token: 'other-token')
      expect(verify(wrong, access_token:).error_type).to eq(:dpop_proof_token_hash)
    end

    it 'refuses a proof without ath' do
      bare = build_dpop_proof(url:)
      expect(verify(bare, access_token:).error_type).to eq(:dpop_proof_token_hash)
    end
  end

  it 'refuses ath when no token is presented' do
    proof = build_dpop_proof(url:, ath: 'abc')
    expect(verify(proof).error_type).to eq(:dpop_proof_token_hash)
  end

  context 'bound to another key' do
    let(:expected_thumbprint) { dpop_thumbprint(OpenSSL::PKey::EC.generate('prime256v1')) }

    it 'fails with a key mismatch and does not consume the jti' do
      expect(result.error_type).to eq(:dpop_key_mismatch)
      expect(result.error_message).to eq(t('openid_connect.token.errors.dpop_key_mismatch'))
      expect(verify(proof)).to be_success
    end
  end

  context 'bound to this key' do
    let(:expected_thumbprint) { dpop_thumbprint }

    it 'succeeds' do
      expect(result).to be_success
    end
  end

  describe 'rejections' do
    it 'missing proof' do
      result = verify(nil)
      expect(result.error_type).to eq(:dpop_proof_missing)
      expect(result.error_message).to eq(t('openid_connect.token.errors.dpop_proof_required'))
    end

    it 'not a JWT' do
      result = verify('nope')
      expect(result.error_type).to eq(:dpop_proof_malformed)
      expect(result.error_message).to eq(t('openid_connect.token.errors.dpop_proof_invalid'))
    end

    it 'wrong typ' do
      proof = build_dpop_proof(url:, header: { typ: 'JWT' })
      expect(verify(proof).error_type).to eq(:dpop_proof_type)
    end

    it 'symmetric algorithm' do
      payload = { jti: 'x', htm: method, htu: url, iat: Time.zone.now.to_i }
      proof = JWT.encode(payload, 'secret', 'HS256', typ: 'dpop+jwt', jwk: dpop_jwk)
      expect(verify(proof).error_type).to eq(:dpop_proof_algorithm)
    end

    it 'alg none' do
      payload = { jti: 'x', htm: method, htu: url, iat: Time.zone.now.to_i }
      proof = JWT.encode(payload, nil, 'none', typ: 'dpop+jwt', jwk: dpop_jwk)
      expect(verify(proof).error_type).to eq(:dpop_proof_algorithm)
    end

    it 'no jwk header' do
      proof = build_dpop_proof(url:, header: { jwk: nil })
      expect(verify(proof).error_type).to eq(:dpop_proof_key)
    end

    it 'jwk carrying the private key' do
      private_jwk = JWT::JWK.new(dpop_key).export(include_private: true)
      proof = build_dpop_proof(url:, header: { jwk: private_jwk })
      expect(verify(proof).error_type).to eq(:dpop_proof_private_key)
    end

    it 'signature by a key other than the one in jwk' do
      other = OpenSSL::PKey::EC.generate('prime256v1')
      proof = build_dpop_proof(url:, key: other, header: { jwk: dpop_jwk })
      expect(verify(proof).error_type).to eq(:dpop_proof_signature)
    end

    it 'wrong method' do
      proof = build_dpop_proof(url:, method: 'GET')
      expect(verify(proof).error_type).to eq(:dpop_proof_method)
    end

    it 'wrong URL' do
      proof = build_dpop_proof(url: 'https://idp.example.gov/api/openid_connect/userinfo')
      expect(verify(proof).error_type).to eq(:dpop_proof_uri)
    end

    it 'htu with a different port' do
      proof = build_dpop_proof(url: 'https://idp.example.gov:8443/api/openid_connect/token')
      expect(verify(proof).error_type).to eq(:dpop_proof_uri)
    end

    it 'iat older than the window' do
      proof = build_dpop_proof(url:, iat: 6.minutes.ago.to_i)
      expect(verify(proof).error_type).to eq(:dpop_proof_issued_at)
    end

    it 'iat further in the future than the window' do
      proof = build_dpop_proof(url:, iat: 6.minutes.from_now.to_i)
      expect(verify(proof).error_type).to eq(:dpop_proof_issued_at)
    end

    it 'iat within the window either side' do
      expect(verify(build_dpop_proof(url:, iat: 4.minutes.ago.to_i))).to be_success
      expect(verify(build_dpop_proof(url:, iat: 4.minutes.from_now.to_i))).to be_success
    end

    it 'iat that is not an integer' do
      proof = build_dpop_proof(url:, iat: Time.zone.now.to_f)
      expect(verify(proof).error_type).to eq(:dpop_proof_issued_at)
    end

    it 'missing jti' do
      proof = build_dpop_proof(url:, jti: nil)
      expect(verify(proof).error_type).to eq(:dpop_proof_signature)
    end
  end

  describe '.thumbprint' do
    it 'is the same for a raw key, a JWK and its exported parameters' do
      from_key = described_class.thumbprint(dpop_key)
      expect(described_class.thumbprint(JWT::JWK.new(dpop_key))).to eq(from_key)
      expect(described_class.thumbprint(dpop_jwk)).to eq(from_key)
      expect(from_key).to match(/\A[A-Za-z0-9_-]{43}\z/)
    end
  end

  describe '.normalize_url' do
    it 'lowercases scheme and host, drops default ports, query, fragment and trailing slash' do
      expect(described_class.normalize_url('HTTP://Example.GOV:80/a/b/?q=1#f'))
        .to eq('http://example.gov/a/b')
      expect(described_class.normalize_url('https://example.gov:8443/')).to eq('https://example.gov:8443')
    end

    it 'is nil for anything that is not an HTTP URL' do
      expect(described_class.normalize_url('mailto:a@b.gov')).to be_nil
      expect(described_class.normalize_url('not a url')).to be_nil
    end
  end
end
