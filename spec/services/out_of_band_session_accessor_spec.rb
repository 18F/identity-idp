require 'rails_helper'

RSpec.describe OutOfBandSessionAccessor do
  let(:session_uuid) { SecureRandom.uuid }

  subject(:store) { described_class.new(session_uuid) }

  around do |ex|
    REDIS_POOL.with { |client| client.flushdb }
    ex.run
    REDIS_POOL.with { |client| client.flushdb }
  end

  describe '#ttl' do
    it 'returns the remaining time-to-live of the session data in redis' do
      store.put_pii({ first_name: 'Fakey' }, 5.minutes.to_i)

      expect(store.ttl).to eq(5.minutes.to_i)
    end

    it 'returns the remaining time-to-live of the session data in redis' do
      store.put_pii({ first_name: 'Fakey' }, 5.minutes.to_i)

      expect(store.ttl).to eq(5.minutes.to_i)
    end

    context 'with reading and writing public_id enabled' do
      it 'returns the TTL' do
        allow(IdentityConfig.store).to receive(:redis_session_read_public_id).and_return(true)
        allow(IdentityConfig.store).to receive(:redis_session_write_public_id).and_return(true)

        options = Rails.application.config.session_options.deep_dup
        options[:redis][:write_public_id] = true
        options[:redis][:write_private_id] = false
        session_store = RedisSessionStore.new({}, options)
        old_store = described_class.new(session_uuid, session_store)

        old_store.put_pii({ first_name: 'Fakey' }, 5.minutes.to_i)

        expect(store.ttl).to eq(5.minutes.to_i)
      end
    end

    context 'with reading public_id enabled and write public_id disabled' do
      it 'returns the TTL whether it was written to the private_id key or private_id key' do
        allow(IdentityConfig.store).to receive(:redis_session_read_public_id).and_return(true)
        allow(IdentityConfig.store).to receive(:redis_session_write_public_id).and_return(false)

        old_store = described_class.new(session_uuid)
        old_store.put_pii({ first_name: 'Fakey' }, 5.minutes.to_i)
        expect(old_store.ttl).to eq(5.minutes.to_i)

        allow(IdentityConfig.store).to receive(:redis_session_write_public_id).and_return(true)

        new_store = described_class.new(session_uuid)
        new_store.put_pii({ first_name: 'Fakey2' }, 5.minutes.to_i)

        expect(old_store.ttl).to eq(5.minutes.to_i)
      end
    end

    context 'with reading and writing public_id disabled' do
      it 'returns the TTL' do
        allow(IdentityConfig.store).to receive(:redis_session_read_public_id).and_return(false)
        allow(IdentityConfig.store).to receive(:redis_session_write_public_id).and_return(false)

        store.put_pii({ first_name: 'Fakey' }, 5.minutes.to_i)

        expect(store.ttl).to eq(5.minutes.to_i)
      end
    end
  end

  describe '#load_pii' do
    it 'loads PII from the session' do
      store.put_pii({ dob: '1970-01-01' }, 5.minutes.to_i)

      pii = store.load_pii
      expect(pii).to be_kind_of(Pii::Attributes)
      expect(pii.dob).to eq('1970-01-01')
    end
  end

  describe '#load_x509' do
    it 'loads X509 attributes from the session' do
      store.put_x509({ subject: 'O=US, OU=DoD, CN=John.Doe.1234' }, 5.minutes.to_i)

      x509 = store.load_x509
      expect(x509).to be_kind_of(X509::Attributes)
      expect(x509.subject).to eq('O=US, OU=DoD, CN=John.Doe.1234')
    end
  end

  describe '#destroy' do
    it 'destroys the session' do
      store.put_pii({ first_name: 'Fakey' }, 5.minutes.to_i)
      store.destroy

      expect(store.load_pii).to be_nil
    end
  end
end
