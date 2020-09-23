require 'rails_helper'

RSpec.describe EncryptedRedisStructStorage do
  let(:id) { SecureRandom.uuid }

  let(:struct_class) do
    Struct.new(:id, :a, :b, :c, keyword_init: true) do
      def self.redis_key_prefix
        'example:prefix'
      end
    end
  end

  describe '.key' do
    subject(:key) { EncryptedRedisStructStorage.key(id, type: struct_class) }

    context 'with a struct that has a redis_key_prefix' do
      it 'prefixes the id' do
        expect(key).to eq("example:prefix:#{id}")
      end
    end

    context 'with a struct that does not have a redis_key_prefix' do
      let(:struct_class) do
        Struct.new(:id, :a, :b, :c)
      end

      it 'raises an error with a message describing what to define' do
        expect { key }.to raise_error(/to have defined class method redis_key_prefix/)
      end
    end
  end

  describe '.load' do
    subject(:load_struct) { EncryptedRedisStructStorage.load(id, type: struct_class) }

    it 'returns nil if no data exists' do
      expect(load_struct).to eq(nil)
    end

    context 'with an empty id' do
      let(:id) { '' }

      it 'is nil' do
        expect(load_struct).to eq(nil)
      end
    end

    context 'with a keyword init struct' do
      it 'loads the value out of redis' do
        EncryptedRedisStructStorage.store(struct_class.new(id: id, a: 'a', b: 'b', c: 'c'))

        loaded_result = load_struct

        expect(loaded_result.a).to eq('a')
        expect(loaded_result.b).to eq('b')
        expect(loaded_result.c).to eq('c')
      end
    end

    context 'with an ordered initializer struct' do
      let(:struct_class) do
        Struct.new(:id, :d, :e, :f, keyword_init: false) do
          def self.redis_key_prefix
            'abcdef'
          end
        end
      end

      it 'loads the value out of redis' do
        EncryptedRedisStructStorage.store(
          struct_class.new(id, 'd', 'e', 'f'),
        )

        loaded_result = load_struct

        expect(loaded_result.d).to eq('d')
        expect(loaded_result.e).to eq('e')
        expect(loaded_result.f).to eq('f')
      end
    end

    context 'with a struct that does not have a redis_key_prefix' do
      let(:struct_class) do
        Struct.new(:id, :a, :b, :c)
      end

      it 'raises an error with a message describing what to define' do
        expect { load_struct }.to raise_error(/to have defined class method redis_key_prefix/)
      end
    end
  end

  describe '.store' do
    context 'with a struct that does not have an id method' do
      let(:struct_class) do
        Struct.new(:a, :b, :c)
      end

      it 'throws an error describing the missing method' do
        expect do
          EncryptedRedisStructStorage.store(struct_class.new(a: 'a', b: 'b'))
        end.to raise_error(/to have an id property/)
      end
    end

    context 'with a struct that has an id' do
      context 'with an empty id' do
        let(:id) { '' }

        it 'errors' do
          expect { EncryptedRedisStructStorage.store(struct_class.new) }.
            to raise_error(ArgumentError, 'id cannot be empty')
        end
      end

      it 'writes encrypted data to redis' do
        EncryptedRedisStructStorage.store(
          struct_class.new(id: id, a: 'value for a', b: 'value for b', c: 'value for c'),
        )

        data = REDIS_POOL.with do |client|
          client.read(EncryptedRedisStructStorage.key(id, type: struct_class))
        end

        expect(data).to be_a(String)
        expect(data).to_not include('value for a')
        expect(data).to_not include('value for b')
        expect(data).to_not include('value for c')
      end

      it 'stores the value with a ttl (expiration)' do
        EncryptedRedisStructStorage.store(
          struct_class.new(id: id, a: 'value for a', b: 'value for b', c: 'value for c'),
        )

        ttl = REDIS_POOL.with do |client|
          client.pool.with do |redis|
            redis.ttl(EncryptedRedisStructStorage.key(id, type: struct_class))
          end
        end

        expect(ttl).to be <= 60
      end
    end
  end
end
