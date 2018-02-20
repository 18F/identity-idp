require 'rails_helper'

describe AgencyIdentityLinker do
  let(:user) { create(:user) }
  describe '#link_identity' do
    before(:each) { init_env(user) }

    it 'links identities from 2 sps' do
      sp1 = create_identity(user, 'http://localhost:3000', 'UUID1')
      create_identity(user, 'urn:gov:gsa:openidconnect:test', 'UUID2')
      ai = AgencyIdentityLinker.new(sp1).link_identity
      expect(ai.uuid).to eq('UUID1')
      ai = AgencyIdentity.where(user_id: user.id).first
      expect(ai.uuid).to eq('UUID1')
    end

    it 'links identity with 1 sp' do
      sp1 = create_identity(user, 'http://localhost:3000', 'UUID1')
      ai = AgencyIdentityLinker.new(sp1).link_identity
      expect(ai.uuid).to eq('UUID1')
      ai = AgencyIdentity.where(user_id: user.id).first
      expect(ai.uuid).to eq('UUID1')
    end

    it 'does not link identity without an agency_id' do
      sp1 = create_identity(user, 'sp:with:no:agency_id', 'UUID1')
      ai = AgencyIdentityLinker.new(sp1).link_identity
      expect(ai.agency_id).to eq(nil)
      expect(ai.uuid).to eq('UUID1')
      ai = AgencyIdentity.where(user_id: user.id).first
      expect(ai).to eq(nil)
    end

    it 'returns the existing agency_identity if it exists' do
      sp1 = create_identity(user, 'http://localhost:3000', 'UUID1')
      ai = AgencyIdentityLinker.new(sp1).link_identity
      expect(ai.uuid).to eq('UUID1')
      ai = AgencyIdentity.where(user_id: user.id).first
      expect(ai.uuid).to eq('UUID1')
    end
  end

  describe '#sp_identity_from_uuid_and_sp' do
    before(:each) { init_env(user) }

    it 'returns sp_identity if it exists' do
      create_identity(user, 'http://localhost:3000', 'UUID1')
      AgencyIdentity.create(user_id: user.id, agency_id: 1, uuid: 'UUID2')
      sp_identity = AgencyIdentityLinker.sp_identity_from_uuid_and_sp('UUID2',
                                                                      'http://localhost:3000')
      expect(sp_identity.uuid).to eq('UUID1')
      expect(sp_identity.service_provider).to eq('http://localhost:3000')
    end

    it 'returns nil if sp_identity does not exist' do
      sp_identity = AgencyIdentityLinker.sp_identity_from_uuid_and_sp('UUID1',
                                                                      'http://localhost:3000')
      expect(sp_identity).to eq(nil)
    end
  end

  describe '#sp_identity_from_uuid' do
    before(:each) { init_env(user) }

    it 'returns sp_identity if it exists' do
      create_identity(user, 'http://localhost:3000', 'UUID1')
      AgencyIdentity.create(user_id: user.id, agency_id: 1, uuid: 'UUID2')
      sp_identity = AgencyIdentityLinker.sp_identity_from_uuid('UUID2')
      expect(sp_identity.uuid).to eq('UUID1')
      expect(sp_identity.service_provider).to eq('http://localhost:3000')
    end

    it 'returns nil if sp_identity does not exist' do
      sp_identity = AgencyIdentityLinker.sp_identity_from_uuid('UUID1')
      expect(sp_identity).to eq(nil)
    end
  end

  def init_env(user)
    allow(Figaro.env).to receive(:enable_agency_based_uuids).and_return('true')
    allow(Figaro.env).to receive(:agencies_with_agency_based_uuids).and_return('1,2,3')
    Identity.where(user_id: user.id).delete_all
    AgencyIdentity.where(user_id: user.id).delete_all
  end

  def create_identity(user, service_provider, uuid)
    Identity.create(user_id: user.id, service_provider: service_provider, uuid: uuid)
  end
end
