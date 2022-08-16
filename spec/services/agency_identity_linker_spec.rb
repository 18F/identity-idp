require 'rails_helper'

describe AgencyIdentityLinker do
  let(:user) { create(:user) }
  describe '#link_identity' do
    before(:each) { init_env(user) }

    it 'links identities from 2 sps' do
      sp1 = create_service_provider_identity(user, 'http://localhost:3000', 'UUID1')
      create_service_provider_identity(user, 'urn:gov:gsa:openidconnect:test', 'UUID2')
      ai = AgencyIdentityLinker.new(sp1).link_identity
      expect(ai.uuid).to eq('UUID1')
      ai = AgencyIdentity.where(user_id: user.id).first
      expect(ai.uuid).to eq('UUID1')
    end

    it 'does not allow 2 sp uuids to be reused after user deletes account' do
      create_service_provider_identity(user, 'http://localhost:3000', 'UUID1')
      create_service_provider_identity(user, 'urn:gov:gsa:openidconnect:test', 'UUID2')
      user.destroy!
      expect(User.where(id: user.id).count).to eq(0)
      user2 = create(:user)
      expect { create_service_provider_identity(user2, 'sp3', 'UUID1') }.
        to raise_error ActiveRecord::RecordNotUnique
      expect { create_service_provider_identity(user2, 'sp4', 'UUID2') }.
        to raise_error ActiveRecord::RecordNotUnique
    end

    it 'does not allow agency_identity uuid to be reused after user deletes account' do
      sp1 = create_service_provider_identity(user, 'http://localhost:3000', 'UUID1')
      create_service_provider_identity(user, 'urn:gov:gsa:openidconnect:test', 'UUID2')
      AgencyIdentityLinker.new(sp1).link_identity
      expect(AgencyIdentity.where(user_id: user.id).count).to eq(1)
      expect(AgencyIdentity.where(uuid: 'UUID1').count).to eq(1)
      user.destroy!
      expect(User.where(id: user.id).count).to eq(0)
      expect(AgencyIdentity.where(user_id: user.id).count).to eq(0)
      expect(AgencyIdentity.where(uuid: 'UUID1').count).to eq(0)
      user2 = create(:user)
      expect { create_service_provider_identity(user2, 'sp3', 'UUID1') }.
        to raise_error ActiveRecord::RecordNotUnique
      expect { create_service_provider_identity(user2, 'sp4', 'UUID2') }.
        to raise_error ActiveRecord::RecordNotUnique
    end

    it 'links identity with 1 sp' do
      sp1 = create_service_provider_identity(user, 'http://localhost:3000', 'UUID1')
      ai = AgencyIdentityLinker.new(sp1).link_identity
      expect(ai.uuid).to eq('UUID1')
      ai = AgencyIdentity.where(user_id: user.id).first
      expect(ai.uuid).to eq('UUID1')
    end

    it 'does not link identity without an agency_id' do
      sp1 = create_service_provider_identity(user, 'sp:with:no:agency_id', 'UUID1')
      ai = AgencyIdentityLinker.new(sp1).link_identity
      expect(ai.agency_id).to eq(nil)
      expect(ai.uuid).to eq('UUID1')
      ai = AgencyIdentity.where(user_id: user.id).first
      expect(ai).to eq(nil)
    end

    it 'returns the existing agency_identity if it exists' do
      sp1 = create_service_provider_identity(user, 'http://localhost:3000', 'UUID1')
      ai = AgencyIdentityLinker.new(sp1).link_identity
      expect(ai.uuid).to eq('UUID1')
      ai = AgencyIdentity.where(user_id: user.id).first
      expect(ai.uuid).to eq('UUID1')
    end
  end

  describe '#sp_identity_from_uuid_and_sp' do
    before(:each) { init_env(user) }

    it 'returns sp_identity if it exists' do
      create_service_provider_identity(user, 'http://localhost:3000', 'UUID1')
      AgencyIdentity.create(user_id: user.id, agency_id: 1, uuid: 'UUID2')
      sp_identity = AgencyIdentityLinker.sp_identity_from_uuid_and_sp(
        'UUID2',
        'http://localhost:3000',
      )
      expect(sp_identity.uuid).to eq('UUID1')
      expect(sp_identity.service_provider).to eq('http://localhost:3000')
    end

    it 'returns nil if sp_identity does not exist' do
      sp_identity = AgencyIdentityLinker.sp_identity_from_uuid_and_sp(
        'UUID1',
        'http://localhost:3000',
      )
      expect(sp_identity).to eq(nil)
    end
  end

  describe '#for' do
    before(:each) { init_env(user) }
    let(:sp) { create(:service_provider) }
    let(:agency) { sp.agency }
    let(:uuid) { SecureRandom.uuid }

    subject { described_class.for(user: user, service_provider: sp) }

    context 'when there is already an agency identity' do
      before { create_agency_identity(user, agency, uuid) }

      it 'returns the existing agency identity' do
        expect(subject).not_to be_nil
        expect(subject.user_id).to eq user.id
        expect(subject.agency_id).to eq agency.id
        expect(subject.uuid).to eq uuid
      end
    end

    context 'when there is not an agency identity' do
      context 'but there is a service provider identity' do
        before { create_service_provider_identity(user, sp.issuer, uuid) }
        it 'returns the service provider identity' do
          expect(subject).not_to be_nil
          expect(subject.user_id).to eq user.id
          expect(subject.agency_id).to eq agency.id
          expect(subject.uuid).to eq uuid
        end

        it 'persists the service provider identity as an agency identity' do
          expect(subject.uuid).to eq uuid
          ai = AgencyIdentity.where(user: user, agency: agency).take
          expect(subject).to eq ai
        end
      end

      context 'and there is no service provider identity' do
        it 'returns nil' do
          expect(subject).to be_nil
        end
      end
    end
  end

  def init_env(user)
    ServiceProviderIdentity.where(user_id: user.id).delete_all
    AgencyIdentity.where(user_id: user.id).delete_all
  end

  def create_service_provider_identity(user, service_provider, uuid)
    ServiceProviderIdentity.create(user_id: user.id, service_provider: service_provider, uuid: uuid)
  end

  def create_agency_identity(user, agency, uuid)
    AgencyIdentity.create!(user: user, agency: agency, uuid: uuid)
  end
end
