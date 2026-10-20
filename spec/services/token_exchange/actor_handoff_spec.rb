require 'rails_helper'

RSpec.describe TokenExchange::ActorHandoff do
  describe '.store and .load' do
    let(:code) { SecureRandom.uuid }

    it 'round trips the actor return-log id without storing the raw code as the key' do
      described_class.store(code:, actor_return_log_id: 123, expires_in: 60)

      expect(described_class.load(code).actor_return_log_id).to eq(123)
      expect(described_class.digest(code)).to_not include(code)
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
