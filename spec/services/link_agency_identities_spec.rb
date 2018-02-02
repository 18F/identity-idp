require 'rails_helper'

describe LinkAgencyIdentities do
  describe '#link' do
    let(:user) { create(:user) }
    before(:each) { init_db(user) }

    it 'migrates a user with two sps' do
      create_identity(user, 'http://localhost:3000', 'UUID1')
      create_identity(user, 'urn:gov:gsa:openidconnect:test', 'UUID2')
      LinkAgencyIdentities.new.link
      ai = AgencyIdentity.where(user_id: user.id).first
      expect(ai.uuid).to eq('UUID1')
    end

    it 'migrates a user with two sps in uuid_priority order' do
      create_identity(user, 'urn:gov:gsa:openidconnect:test', 'UUID2')
      create_identity(user, 'http://localhost:3000', 'UUID1')
      LinkAgencyIdentities.new.link
      ai = AgencyIdentity.where(user_id: user.id).first
      expect(ai.uuid).to eq('UUID1')
    end

    it 'links identity with 1 sp' do
      create_identity(user, 'http://localhost:3000', 'UUID1')
      LinkAgencyIdentities.new.link
      ai = AgencyIdentity.where(user_id: user.id).first
      expect(ai.uuid).to eq('UUID1')
    end

    it 'does not link identity without an agency_id' do
      create_identity(user, 'sp:with:no:agent_id', 'UUID1')
      LinkAgencyIdentities.new.link
      ai = AgencyIdentity.where(user_id: user.id).first
      expect(ai).to eq(nil)
    end
  end

  def init_db(user)
    Identity.where(user_id: user.id).delete_all
    AgencyIdentity.where(user_id: user.id).delete_all
  end

  def create_identity(user, service_provider, uuid)
    Identity.create(user_id: user.id, service_provider: service_provider, uuid: uuid)
  end
end
