require 'rails_helper'

RSpec.describe AttemptsApi::RequestTokenValidator do
  let(:sp) { create(:service_provider) }
  let(:issuer) { sp.issuer }
  let(:token) { 'a-shared-secret' }
  let(:salt) { SecureRandom.hex(32) }
  let(:cost) { IdentityConfig.store.scrypt_cost }

  let(:hashed_token) do
    scrypt_salt = cost + OpenSSL::Digest::SHA256.hexdigest(salt)
    scrypted = SCrypt::Engine.hash_secret token, scrypt_salt, 32
    SCrypt::Password.new(scrypted).digest
  end

  let(:auth_header) { "Bearer #{issuer} #{token}" }

  before do
    allow(IdentityConfig.store).to receive(:allowed_attempts_providers).and_return(
      [{
        issuer: sp.issuer,
        tokens: [{ value: hashed_token, salt: }],
      }],
    )
  end

  subject { AttemptsApi::RequestTokenValidator.new(auth_header) }

  describe 'validations' do
    context 'with a valid auth header' do
      it 'returns true' do
        expect(subject.valid?).to be true
      end
    end

    context 'with no auth header' do
      let(:auth_header) { nil }

      it 'returns false' do
        expect(subject.valid?).to be false
      end
    end

    context 'with an empty string for auth header' do
      let(:auth_header) { '' }

      it 'returns false' do
        expect(subject.valid?).to be false
      end
    end

    context 'without a Bearer token' do
      let(:auth_header) { "#{sp.issuer} #{token}" }

      it 'returns false' do
        expect(subject.valid?).to be false
      end
    end

    context 'without a valid issuer' do
      context 'with an unknown issuer' do
        let(:issuer) { 'unknown-issuer' }

        it 'returns false' do
          expect(subject.valid?).to be false
        end
      end

      context 'with an issuer associated with an unauthorized sp' do
        let(:unauth_sp) { create(:service_provider) }
        let(:issuer) { unauth_sp.issuer }

        it 'returns false' do
          expect(subject.valid?).to be false
        end
      end
    end

    context 'without a token' do
      let(:token) { nil }

      it 'returns false' do
        expect(subject.valid?).to be false
      end
    end

    context 'with an invalid token' do
      let(:auth_header) { "Bearer #{issuer} not-shared-secret" }

      it 'returns false' do
        expect(subject.valid?).to be false
      end
    end
  end
end
