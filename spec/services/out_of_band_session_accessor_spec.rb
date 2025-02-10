require 'rails_helper'

RSpec.describe OutOfBandSessionAccessor do
  let(:session_uuid) { SecureRandom.uuid }
  let(:profile_id) { 123 }

  # This test uses a separate writer instance to write test data to the session store.
  # The OutOfBandSessionAccessor memoizes the data that it reads from the session.
  # Writes require reads to merge test data properly for subsequent writes.
  subject(:writer_instance) { described_class.new(session_uuid) }

  subject(:store) { described_class.new(session_uuid) }

  around do |ex|
    REDIS_POOL.with { |client| client.flushdb }
    ex.run
    REDIS_POOL.with { |client| client.flushdb }
  end

  describe '#ttl' do
    it 'returns the remaining time-to-live of the session data in redis' do
      store.put_pii(
        profile_id: profile_id,
        pii: { first_name: 'Fakey' },
        expiration: 5.minutes.in_seconds,
      )

      expect(store.ttl).to be_within(1).of(5.minutes.in_seconds)
    end
  end

  describe '#load_web_locale' do
    it 'loads the web_locale from the session' do
      writer_instance.put_locale('es')

      web_locale = store.load_web_locale
      expect(web_locale).to eq('es')
    end
  end

  describe '#load_pii' do
    it 'loads PII from the session' do
      writer_instance.put_pii(
        profile_id: profile_id,
        pii: { dob: '1970-01-01' },
        expiration: 5.minutes.in_seconds,
      )

      pii = store.load_pii(profile_id)
      expect(pii).to be_kind_of(Pii::Attributes)
      expect(pii.dob).to eq('1970-01-01')
    end
  end

  describe '#load_x509' do
    it 'loads X509 attributes from the session' do
      writer_instance.put_x509({ subject: 'O=US, OU=DoD, CN=John.Doe.1234' }, 5.minutes.in_seconds)

      x509 = store.load_x509
      expect(x509).to be_kind_of(X509::Attributes)
      expect(x509.subject).to eq('O=US, OU=DoD, CN=John.Doe.1234')
    end
  end

  describe '#destroy' do
    it 'destroys the session' do
      writer_instance.put_pii(
        profile_id: profile_id,
        pii: { first_name: 'Fakey' },
        expiration: 5.minutes.in_seconds,
      )
      store.destroy

      expect(store.load_pii(profile_id)).to be_nil
    end
  end
end
