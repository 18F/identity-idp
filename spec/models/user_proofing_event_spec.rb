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

  describe '#add_sp_sent' do
    let(:issuer) { 'a:test:issuer' }

    before do
      user_proofing_event.add_sp_sent(issuer)
    end

    it 'should add a given issuer to the list of service_providers_sent' do
      expect(user_proofing_event.service_providers_sent).to eq([issuer])
    end

    it 'should be idempotent' do
      expect(user_proofing_event.service_providers_sent.length).to eq(1)

      user_proofing_event.add_sp_sent(issuer)

      expect(user_proofing_event.service_providers_sent).to eq([issuer])
    end
  end
end
