require 'rails_helper'

RSpec.describe X509::SessionStore do
  let(:session_uuid) { SecureRandom.uuid }

  subject(:store) { X509::SessionStore.new(session_uuid) }

  describe '#ttl' do
    it 'returns the remaining time-to-live of the session data in redis' do
      store.put({ subject: 'O=US, OU=DoD, CN=John.Doe.1234' }, 5.minutes.to_i)

      expect(store.ttl).to eq(5.minutes.to_i)
    end
  end

  describe '#load' do
    it 'loads X509 data from the session' do
      store.put({ subject: 'O=US, OU=DoD, CN=John.Doe.1234' }, 5.minutes.to_i)

      x509 = store.load
      expect(x509).to be_kind_of(X509::Attributes)
      expect(x509.subject).to eq('O=US, OU=DoD, CN=John.Doe.1234')
    end
  end
end
