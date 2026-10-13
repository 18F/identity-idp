require 'rails_helper'

RSpec.describe AccountRecovery::TokenCreator do
  before do
    allow(IdentityConfig.store).to receive(:account_recovery_token_valid_for_hours).and_return(24)
  end

  describe '.call' do
    it 'returns a url-safe raw token with at least 128 bits of entropy' do
      token = described_class.call

      expect(token.raw).to match(/\A[A-Za-z0-9_-]+\z/)
      expect(token.raw.length).to be >= 22
    end

    it 'returns a fingerprint that is not the raw token' do
      token = described_class.call

      expect(token.fingerprint).to be_present
      expect(token.fingerprint).to_not eq(token.raw)
      expect(token.fingerprint).to eq(described_class.fingerprint(token.raw))
    end

    it 'expires within the configured window' do
      freeze_time do
        token = described_class.call

        expect(token.expires_at).to eq(Time.zone.now + 24.hours)
      end
    end

    it 'does not repeat tokens' do
      tokens = Array.new(5) { described_class.call.raw }

      expect(tokens.uniq.length).to eq(5)
    end
  end

  describe '.fingerprint' do
    it 'is deterministic for the same input' do
      expect(described_class.fingerprint('abc')).to eq(described_class.fingerprint('abc'))
    end

    it 'differs for different inputs' do
      expect(described_class.fingerprint('abc')).to_not eq(described_class.fingerprint('abd'))
    end
  end
end
