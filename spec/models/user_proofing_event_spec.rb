require 'rails_helper'

RSpec.describe UserProofingEvent, type: :model do
  let(:user_proofing_event) do
    UserProofingEvent.new(
      encrypted_events: 'these_events_are_encrypted',
      profile_id: 1,
      service_providers_sent: [],
      cost: '0$cost$',
      salt: 'salt0',
    )
  end

  describe '#update_encrypted_events' do
    let(:encrypted_events) { 'new_encrypted_events' }
    let(:cost) { '1$cost$' }
    let(:salt) { 'salt1' }
    let(:new_events) do
      {
        encrypted_events:,
        cost:,
        salt:,
      }.to_json
    end

    before do
      user_proofing_event.update_encrypted_events(new_events)
    end

    it 'updates encrypted events' do
      expect(user_proofing_event.encrypted_events).to eq(new_events)
    end

    it 'updates cost' do
      expect(user_proofing_event.cost).to eq(cost)
    end

    it 'updates salt' do
      expect(user_proofing_event.salt).to eq(salt)
    end
  end
end
