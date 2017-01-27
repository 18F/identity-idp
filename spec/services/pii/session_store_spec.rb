require 'rails_helper'

RSpec.describe Pii::SessionStore do
  let(:session_uuid) { SecureRandom.uuid }

  subject(:store) { Pii::SessionStore.new(session_uuid) }

  describe '#ttl' do
    it 'returns the remaining time-to-live of the session data in redis' do
      store.put({ dob: '1970-01-01' }, 5.minutes.to_i)

      expect(store.ttl).to eq(5.minutes.to_i)
    end
  end

  describe '#load' do
    it 'loads PII from the session' do
      store.put({ dob: '1970-01-01' }, 5.minutes.to_i)

      pii = store.load
      expect(pii).to be_kind_of(Pii::Attributes)
      expect(pii.dob).to eq('1970-01-01')
    end
  end
end
