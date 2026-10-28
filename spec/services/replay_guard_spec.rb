require 'rails_helper'

RSpec.describe ReplayGuard do
  # Redis is shared across examples, so every example presents its own values.
  let(:namespace) { 'dpop:jti' }
  let(:scope) { SecureRandom.hex }
  let(:value) { SecureRandom.hex }
  let(:ttl) { 60 }

  describe '.first_use?' do
    let(:result) { described_class.first_use?(namespace:, scope:, value:, ttl:) }
    context 'when the value has not been seen' do
      it 'accepts the value' do
        expect(result).to eq(true)
      end
    end

    context 'when the value has already been seen' do
      before do
        result
      end
      it 'refuses the value' do
        expect(described_class.first_use?(namespace:, scope:, value:, ttl:)).to eq(false)
      end
    end

    context 'when the value is recorded' do
      let(:ttl) { 120 }
      let(:key) { described_class.key(namespace:, scope:, value:) }

      before do
        result
      end

      it 'keeps the value for the given ttl' do
        expect(REDIS_POOL.with { |client| client.ttl(key) }).to be_between(115, 120)
      end
    end

    context 'when the same value uses a different scope' do
      let(:other_scope) { SecureRandom.hex }
      let(:other_result) do
        described_class.first_use?(namespace:, scope: other_scope, value:, ttl:)
      end

      before do
        result
      end

      it 'accepts the value separately' do
        expect(other_result).to eq(true)
      end
    end

    context 'when the same value uses a different namespace' do
      let(:other_namespace) { 'client-assertion:jti' }
      let(:other_result) do
        described_class.first_use?(namespace: other_namespace, scope:, value:, ttl:)
      end

      before do
        result
      end

      it 'accepts the value separately' do
        expect(other_result).to eq(true)
      end
    end

    context 'when the value is nil' do
      let(:value) { nil }

      it 'refuses the value' do
        expect(result).to eq(false)
      end
    end

    context 'when the value is empty' do
      let(:value) { '' }

      it 'refuses the value' do
        expect(result).to eq(false)
      end
    end

    context 'when the value is not a string' do
      let(:value) { 1 }

      it 'refuses the value' do
        expect(result).to eq(false)
      end
    end
  end

  describe '.key' do
    let(:key) { described_class.key(namespace:, scope:, value:) }
    let(:hashed_value) { Digest::SHA256.hexdigest("#{scope}\n#{value}") }

    context 'when building a key' do
      it 'prefixes the key with the namespace' do
        expect(key).to start_with("#{namespace}:")
      end
    end

    context 'when the value contains unsafe Redis key characters' do
      let(:value) { "value with spaces\nslashes/and:colons" }

      it 'hashes the scoped value' do
        expect(key).to eq("#{namespace}:#{hashed_value}")
      end
    end

    context 'when the scope changes' do
      let(:other_scope) { SecureRandom.hex }
      let(:other_key) { described_class.key(namespace:, scope: other_scope, value:) }

      it 'returns a different key' do
        expect(other_key).not_to eq(key)
      end
    end

    context 'when the namespace changes' do
      let(:other_namespace) { 'client-assertion:jti' }
      let(:other_key) { described_class.key(namespace: other_namespace, scope:, value:) }

      it 'returns a key in the other namespace' do
        expect(other_key).to start_with("#{other_namespace}:")
      end
    end
  end
end
