require 'rails_helper'

RSpec.describe DpopProofForm do
  let(:http_url) { 'https://idp.example.gov/api/openid_connect/token' }
  let(:http_method) { 'POST' }
  let(:access_token) { nil }
  let(:expected_thumbprint) { nil }
  let(:proof) { build_dpop_proof(http_url:, http_method:, access_token:) }
  let(:first_use) { true }
  let(:payload) { { jti: 'x', htm: http_method, htu: http_url, iat: Time.zone.now.to_i } }

  subject(:result) do
    described_class.new(
      proof:, http_method:, http_url:, access_token:, expected_thumbprint:,
    ).submit
  end

  before do
    allow(ReplayGuard).to receive(:first_use?).and_return(first_use)
  end

  def verify(proof, **options)
    described_class.new(proof:, http_method:, http_url:, **options).submit
  end

  describe '#submit' do
    context 'when the proof is valid' do
      context 'with an ES256 proof' do
        it 'returns a successful result with the key thumbprint' do
          expect(result).to be_success
          expect(result.extra[:dpop_thumbprint]).to eq(dpop_thumbprint)
          expect(result.success?).to eq(true)
          expect(result.errors).to be_empty
        end
      end

      context 'with an RS256 proof' do
        let(:key) { OpenSSL::PKey::RSA.new(2048) }
        let(:proof) { build_dpop_proof(http_url:, key:, header: { alg: 'RS256' }) }

        it 'returns a successful result with the key thumbprint' do
          expect(result).to be_success
          expect(result.extra[:dpop_thumbprint]).to eq(dpop_thumbprint(key))
        end
      end

      context 'when htu matches the request URL after normalization' do
        let(:proof) do
          build_dpop_proof(
            http_url: 'HTTPS://IDP.example.gov:443/api/openid_connect/token?x=1#f',
          )
        end

        it 'accepts the proof' do
          expect(result).to be_success
        end
      end

      context 'when htu has a trailing slash the request URL does not' do
        let(:proof) do
          build_dpop_proof(http_url: 'https://idp.example.gov/api/openid_connect/token/')
        end

        it 'refuses the proof, because /a and /a/ are different URLs' do
          expect(result.success?).to eq(false)
          expect(result.extra[:dpop_error_type]).to eq(:dpop_proof_uri)
        end
      end

      context 'when iat is within the window' do
        it 'accepts the proof' do
          expect(verify(build_dpop_proof(http_url:, iat: 4.minutes.ago.to_i))).to be_success
          expect(verify(build_dpop_proof(http_url:, iat: 4.minutes.from_now.to_i))).to be_success
        end
      end

      context 'when an access token accompanies the proof' do
        let(:access_token) { SecureRandom.urlsafe_base64(32) }

        context 'and ath matches the token' do
          it 'accepts the proof' do
            expect(result).to be_success
          end
        end
      end

      context 'when the expected thumbprint matches the proof key' do
        let(:expected_thumbprint) { dpop_thumbprint }

        it 'accepts the proof' do
          expect(result).to be_success
        end
      end

      context 'when recording the jti in Redis' do
        before do
          allow(ReplayGuard).to receive(:first_use?).and_call_original
        end

        it 'keeps the jti for twice the acceptance window' do
          allow(IdentityConfig.store).to receive(:dpop_proof_max_age_seconds).and_return(120)
          expect(result).to be_success
          key = ReplayGuard.key(
            namespace: described_class::JTI_NAMESPACE,
            scope: dpop_thumbprint,
            value: JWT.decode(proof, nil, false)[0]['jti'],
          )
          expect(REDIS_POOL.with { |client| client.ttl(key) }).to be_between(230, 240)
        end
      end
    end

    context 'when the proof is not valid' do
      context 'when the proof is missing' do
        let(:proof) { nil }
        it 'returns :dpop_proof_missing' do
          expect(result.extra[:dpop_error_type]).to eq(:dpop_proof_missing)
          expect(result.first_error_message)
            .to eq('dpop_proof_missing')
        end
      end

      context 'when the proof is malformed' do
        let(:proof) { 'not a proof!' }
        it 'returns the invalid proof error' do
          expect(result.extra[:dpop_error_type]).to eq(:dpop_proof_malformed)
          expect(result.first_error_message)
            .to eq('dpop_proof_malformed')
        end
      end

      context 'when typ is not dpop+jwt' do
        let(:proof) { build_dpop_proof(http_url:, header: { typ: 'JWT' }) }
        it 'rejects the proof type' do
          expect(result.extra[:dpop_error_type]).to eq(:dpop_proof_type)
          expect(result.first_error_message)
            .to eq('dpop_proof_type')
        end
      end

      context 'when alg is HS256' do
        let(:proof) do
          JWT.encode(payload, 'secret', 'HS256', typ: 'dpop+jwt', jwk: dpop_jwk)
        end
        it 'rejects the algorithm' do
          expect(result.extra[:dpop_error_type]).to eq(:dpop_proof_algorithm)
          expect(result.first_error_message)
            .to eq('dpop_proof_algorithm')
        end
      end

      context 'when alg is none' do
        let(:proof) do
          JWT.encode(payload, nil, 'none', typ: 'dpop+jwt', jwk: dpop_jwk)
        end
        it 'rejects the algorithm' do
          expect(result.extra[:dpop_error_type]).to eq(:dpop_proof_algorithm)
          expect(result.first_error_message)
            .to eq('dpop_proof_algorithm')
        end
      end

      context 'when the jwk header is missing' do
        let(:proof) { build_dpop_proof(http_url:, header: { jwk: nil }) }
        it 'rejects the key' do
          expect(result.extra[:dpop_error_type]).to eq(:dpop_proof_key)
          expect(result.first_error_message)
            .to eq('dpop_proof_key')
        end
      end

      context 'when the jwk carries the private key' do
        let(:jwk) { JWT::JWK.new(dpop_key).export(include_private: true) }
        let(:proof) { build_dpop_proof(http_url:, header: { jwk: }) }
        it 'rejects the key' do
          expect(result.extra[:dpop_error_type]).to eq(:dpop_proof_private_key)
          expect(result.first_error_message)
            .to eq('dpop_proof_private_key')
        end
      end

      context 'when the signature uses a key other than the header jwk' do
        let(:key) { OpenSSL::PKey::EC.generate('prime256v1') }
        let(:proof) { build_dpop_proof(http_url:, key:, header: { jwk: dpop_jwk }) }
        it 'rejects the signature' do
          expect(result.extra[:dpop_error_type]).to eq(:dpop_proof_signature)
          expect(result.first_error_message)
            .to eq('dpop_proof_signature')
        end
      end

      context 'when the jti claim is missing' do
        let(:proof) { build_dpop_proof(http_url:, jti: nil) }
        it 'rejects the signature' do
          expect(result.extra[:dpop_error_type]).to eq(:dpop_proof_signature)
          expect(result.first_error_message)
            .to eq('dpop_proof_signature')
        end
      end

      context 'when htm does not match the request method' do
        let(:proof) { build_dpop_proof(http_url:, http_method: 'GET') }
        it 'rejects the method' do
          expect(result.extra[:dpop_error_type]).to eq(:dpop_proof_method)
          expect(result.first_error_message)
            .to eq('dpop_proof_method')
        end
      end

      context 'when htu has a different path' do
        let(:proof) do
          build_dpop_proof(http_url: 'https://idp.example.gov/api/openid_connect/userinfo')
        end
        it 'rejects the URI' do
          expect(result.extra[:dpop_error_type]).to eq(:dpop_proof_uri)
          expect(result.first_error_message)
            .to eq('dpop_proof_uri')
        end
      end

      context 'when htu has a different port' do
        let(:proof) do
          build_dpop_proof(http_url: 'https://idp.example.gov:8443/api/openid_connect/token')
        end
        it 'rejects the URI' do
          expect(result.extra[:dpop_error_type]).to eq(:dpop_proof_uri)
          expect(result.first_error_message)
            .to eq('dpop_proof_uri')
        end
      end

      context 'when iat is older than the window' do
        let(:proof) { build_dpop_proof(http_url:, iat: 6.minutes.ago.to_i) }
        it 'rejects issued at' do
          expect(result.extra[:dpop_error_type]).to eq(:dpop_proof_issued_at)
          expect(result.first_error_message)
            .to eq('dpop_proof_issued_at')
        end
      end

      context 'when iat is further in the future than the window' do
        let(:proof) { build_dpop_proof(http_url:, iat: 6.minutes.from_now.to_i) }
        it 'rejects issued at' do
          expect(result.extra[:dpop_error_type]).to eq(:dpop_proof_issued_at)
          expect(result.first_error_message)
            .to eq('dpop_proof_issued_at')
        end
      end

      context 'when iat is not an integer' do
        let(:proof) { build_dpop_proof(http_url:, iat: Time.zone.now.to_f) }
        it 'rejects issued at' do
          expect(result.extra[:dpop_error_type]).to eq(:dpop_proof_issued_at)
          expect(result.first_error_message)
            .to eq('dpop_proof_issued_at')
        end
      end

      context 'when an access token accompanies the proof' do
        let(:access_token) { SecureRandom.urlsafe_base64(32) }

        context 'and ath matches a different token' do
          let(:proof) { build_dpop_proof(http_url:, access_token: 'other-token') }
          it 'rejects the token hash' do
            expect(result.extra[:dpop_error_type]).to eq(:dpop_proof_token_hash)
            expect(result.first_error_message)
              .to eq('dpop_proof_token_hash')
          end
        end

        context 'and ath is missing' do
          let(:proof) { build_dpop_proof(http_url:) }
          it 'rejects the token hash' do
            expect(result.extra[:dpop_error_type]).to eq(:dpop_proof_token_hash)
            expect(result.first_error_message)
              .to eq('dpop_proof_token_hash')
          end
        end
      end

      context 'when an access token does not accompany the proof' do
        context 'and ath is present' do
          let(:proof) { build_dpop_proof(http_url:, ath: 'abc') }
          it 'rejects the token hash' do
            expect(result.extra[:dpop_error_type]).to eq(:dpop_proof_token_hash)
            expect(result.first_error_message)
              .to eq('dpop_proof_token_hash')
          end
        end
      end

      context 'when the expected thumbprint does not match the proof key' do
        let(:expected_thumbprint) { dpop_thumbprint(OpenSSL::PKey::EC.generate('prime256v1')) }

        it 'rejects the key binding without consuming the jti' do
          expect(ReplayGuard).not_to receive(:first_use?)
          expect(result.extra[:dpop_error_type]).to eq(:dpop_key_mismatch)
          expect(result.first_error_message)
            .to eq('dpop_key_mismatch')
        end
      end

      context 'when the jti has already been used' do
        let(:first_use) { false }

        it 'rejects the replayed proof' do
          expect(result.extra[:dpop_error_type]).to eq(:dpop_proof_replayed)
          expect(result.first_error_message)
            .to eq('dpop_proof_replayed')
        end
      end
    end
  end

  describe '.thumbprint' do
    let(:thumbprint) { described_class.thumbprint(dpop_key) }

    context 'when the key is a JWK object' do
      it 'returns the same thumbprint as the raw key' do
        expect(described_class.thumbprint(JWT::JWK.new(dpop_key))).to eq(thumbprint)
      end
    end

    context 'when the key is exported JWK parameters' do
      it 'returns the same thumbprint as the raw key' do
        expect(described_class.thumbprint(dpop_jwk)).to eq(thumbprint)
      end
    end

    context 'when the thumbprint is generated' do
      it 'returns base64url SHA-256 output' do
        expect(thumbprint).to match(/\A[A-Za-z0-9_-]{43}\z/)
      end
    end
  end

  describe '.normalize_url' do
    context 'when the URL has uppercase scheme and host' do
      it 'lowercases scheme and host' do
        expect(described_class.normalize_url('HTTP://Example.GOV/a/b'))
          .to eq('http://example.gov/a/b')
      end
    end

    context 'when the URL has the default port' do
      it 'drops the port' do
        expect(described_class.normalize_url('https://example.gov:443/a/b'))
          .to eq('https://example.gov/a/b')
      end
    end

    context 'when the URL has a query and fragment' do
      it 'drops the query and fragment' do
        expect(described_class.normalize_url('https://example.gov/a/b?q=1#f'))
          .to eq('https://example.gov/a/b')
      end
    end

    context 'when the URL has a non-default port' do
      it 'keeps the port' do
        expect(described_class.normalize_url('https://example.gov:8443/'))
          .to eq('https://example.gov:8443/')
      end
    end

    context 'when the URL has no path' do
      it 'reads the path as a single slash, as RFC 3986 scheme-based normalization does' do
        expect(described_class.normalize_url('https://example.gov'))
          .to eq('https://example.gov/')
      end
    end

    context 'when the URL has a trailing slash after a path segment' do
      it 'keeps it, because /a and /a/ are different URLs' do
        expect(described_class.normalize_url('https://example.gov/a/'))
          .to eq('https://example.gov/a/')
        expect(described_class.normalize_url('https://example.gov/a/'))
          .not_to eq(described_class.normalize_url('https://example.gov/a'))
      end
    end

    context 'when the URL is not HTTP' do
      it 'returns nil' do
        expect(described_class.normalize_url('mailto:a@b.gov')).to be_nil
      end
    end

    context 'when the URL is invalid' do
      it 'returns nil' do
        expect(described_class.normalize_url('not a url')).to be_nil
      end
    end
  end
end
