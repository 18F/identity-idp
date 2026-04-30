require 'rails_helper'

RSpec.describe UserProofingEvent, type: :model do
  let(:user_proofing_event) do
    UserProofingEvent.new(
      profile_id: 1,
      service_provider_ids_sent: [],
      cost: '0$cost$',
      salt: 'salt0',
    )
  end

  describe '#add_sp_sent' do
    let(:sp) { create(:service_provider) }

    before do
      user_proofing_event.add_sp_sent(sp.id)
    end

    it 'should add a given id to the list of service_provider_ids_sent' do
      expect(user_proofing_event.service_provider_ids_sent).to eq([sp.id])
    end

    it 'should be idempotent' do
      expect(user_proofing_event.service_provider_ids_sent.length).to eq(1)

      user_proofing_event.add_sp_sent(sp.id)

      expect(user_proofing_event.service_provider_ids_sent).to eq([sp.id])
    end
  end
end
