require 'rails_helper'

RSpec.describe EncryptedRedisStructStorage do
  describe 'including' do
    it 'errors when included in a struct that does not have an id property' do
      expect do
        Struct.new(:not_id) do
          include EncryptedRedisStructStorage
        end
      end.to raise_error(/can only be included in classes that have an id key/)
    end
  end

  describe '.redis_key_prefix' do
    context 'in a struct where the key was configured' do
      it 'returns the key prefix' do
        klass = Struct.new(:id) do
          include EncryptedRedisStructStorage

          configure_encrypted_redis_struct key_prefix: 'abc'
        end

        expect(klass.redis_key_prefix).to eq('abc')
      end
    end

    context 'in a struct where the key was not configured' do
      it 'raises an error with instructions to call configure_encrypted_redis_struct' do
        klass = Struct.new(:id) do
          include EncryptedRedisStructStorage
        end

        expect { klass.redis_key_prefix }.to raise_error(/configure_encrypted_redis_struct/)
      end
    end
  end

  let(:id) { SecureRandom.uuid }
  let(:example_struct) do
    Struct.new(:id, :a, :b, :c, keyword_init: true) do
      include EncryptedRedisStructStorage

      configure_encrypted_redis_struct key_prefix: 'example:struct'
    end
  end

  describe '.key' do
    it 'generates a key' do
      key = example_struct.key(id)
      expect(key).to eq('example:struct:' + id)
    end
  end

  describe '.store' do
    it 'writes encrypted data to redis' do
      example_struct.store(id: id, a: 'value for a', b: 'value for b', c: 'value for c')

      data = REDIS_POOL.with { |client| client.read(example_struct.key(id)) }

      expect(data).to be_a(String)
      expect(data).to_not include('value for a')
      expect(data).to_not include('value for b')
      expect(data).to_not include('value for c')
    end

    it 'stores the value with a ttl (expiration)' do
      example_struct.store(id: id, a: 'value for a', b: 'value for b', c: 'value for c')

      ttl = REDIS_POOL.with do |client|
        client.pool.with do |redis|
          redis.ttl(example_struct.key(id))
        end
      end

      expect(ttl).to be <= 60
    end
  end

  describe '.load' do
    it 'returns nil if no data exists' do
      loaded_result = example_struct.load(SecureRandom.uuid)

      expect(loaded_result).to eq(nil)
    end

    context 'with a keyword init struct' do
      it 'loads the value out of redis' do
        example_struct.store(id: id, a: 'a', b: 'b', c: 'c')

        loaded_result = example_struct.load(id)

        expect(loaded_result.a).to eq('a')
        expect(loaded_result.b).to eq('b')
        expect(loaded_result.c).to eq('c')
      end
    end

    context 'with an ordered initializer struct' do
      let(:example_struct) do
        Struct.new(:id, :d, :e, :f, keyword_init: false) do
          include EncryptedRedisStructStorage

          configure_encrypted_redis_struct key_prefix: 'example:struct'
        end
      end

      it 'loads the value out of redis' do
        example_struct.store(id: id, d: 'd', e: 'e', f: 'f')

        loaded_result = example_struct.load(id)

        expect(loaded_result.d).to eq('d')
        expect(loaded_result.e).to eq('e')
        expect(loaded_result.f).to eq('f')
      end
    end
  end
end
