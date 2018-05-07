require 'rails_helper'

describe LinkAgencyIdentities do
  describe '#link' do
    let(:user) { create(:user) }
    before(:each) { init_env(user) }

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

  describe '#report' do
    let(:user) { create(:user) }
    before(:each) { init_env(user) }

    it 'migrates a user with two sps and reports' do
      create_identity(user, 'http://localhost:3000', 'UUID1')
      create_identity(user, 'urn:gov:gsa:openidconnect:test', 'UUID2')
      LinkAgencyIdentities.new.link
      report = LinkAgencyIdentities.report
      expect(report[0]['name']).to eq('CBP')
      expect(report[0]['old_uuid']).to eq('UUID2')
      expect(report[0]['new_uuid']).to eq('UUID1')
      expect(report.cmd_tuples).to eq(1)
    end

    it 'migrates a user with two sps in uuid_priority order and reports' do
      create_identity(user, 'urn:gov:gsa:openidconnect:test', 'UUID2')
      create_identity(user, 'http://localhost:3000', 'UUID1')
      LinkAgencyIdentities.new.link
      report = LinkAgencyIdentities.report
      expect(report[0]['name']).to eq('CBP')
      expect(report[0]['old_uuid']).to eq('UUID2')
      expect(report[0]['new_uuid']).to eq('UUID1')
      expect(report.cmd_tuples).to eq(1)
    end

    it 'links identity with 1 sp and reports no change' do
      create_identity(user, 'http://localhost:3000', 'UUID1')
      LinkAgencyIdentities.new.link
      report = LinkAgencyIdentities.report
      expect(report.cmd_tuples).to eq(0)
    end

    it 'does not link identity without an agency_id' do
      create_identity(user, 'sp:with:no:agent_id', 'UUID1')
      LinkAgencyIdentities.new.link
      report = LinkAgencyIdentities.report
      expect(report.cmd_tuples).to eq(0)
    end
  end

  def init_env(user)
    AgencySeeder.new(rails_env: Rails.env, deploy_env: Rails.env).run
    Identity.where(user_id: user.id).delete_all
    AgencyIdentity.where(user_id: user.id).delete_all
  end

  def create_identity(user, service_provider, uuid)
    Identity.create(user_id: user.id, service_provider: service_provider, uuid: uuid)
  end
end
