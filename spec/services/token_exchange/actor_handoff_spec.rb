require 'rails_helper'

RSpec.describe TokenExchange::ActorHandoff do
  describe '.store and .load' do
    let(:code) { SecureRandom.uuid }

    it 'round trips the actor return-log id without storing the raw code as the key' do
      described_class.store(code:, actor_return_log_id: 123, expires_in: 60)

      expect(described_class.load(code).actor_return_log_id).to eq(123)
      expect(described_class.load(code).dpop_jkt).to be_nil
      expect(described_class.digest(code)).to_not include(code)
    end

    context 'with the thumbprint of the key named at authorization' do
      let(:dpop_jkt) { SecureRandom.urlsafe_base64(32) }

      it 'round trips the thumbprint' do
        described_class.store(code:, actor_return_log_id: nil, dpop_jkt:, expires_in: 60)

        expect(described_class.load(code).dpop_jkt).to eq(dpop_jkt)
      end
    end

    it 'uses the requested expiration' do
      expect(EncryptedRedisStructStorage).to receive(:store).with(
        instance_of(described_class),
        expires_in: 60,
      )

      described_class.store(code:, actor_return_log_id: 123, expires_in: 60)
    end
  end
end
