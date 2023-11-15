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
      store.put_pii(123, { first_name: 'Fakey' }, 5.minutes.to_i)

      expect(store.ttl).to be_within(1).of(5.minutes.to_i)
    end
  end

  describe '#load_pii' do
    it 'loads PII from the session' do
      store.put_pii(123, { dob: '1970-01-01' }, 5.minutes.to_i)

      pii = store.load_pii(123)
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
      store.put_pii(123, { first_name: 'Fakey' }, 5.minutes.to_i)
      store.destroy

      expect(store.load_pii(123)).to be_nil
    end
  end
end
