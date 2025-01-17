require 'rails_helper'

RSpec.describe Idv::SocureUser do
  around do |ex|
    REDIS_SOCURE_USERS_POOL.with { |client| client.flushdb }
    ex.run
    REDIS_SOCURE_USERS_POOL.with { |client| client.flushdb }
  end

  let(:socure_user_set) { Idv::SocureUser.new }
  let(:dummy_uuid_1) { 001 }
  let(:dummy_uuid_2) { 002 }
  let(:dummy_uuid_3) { 003 }


  describe '#add_user!' do
    before do
      allow(IdentityConfig.store).to receive(:doc_auth_socure_max_allowed_users).and_return(2)
    end
    
    it 'correctly adds user and tracks count' do
      socure_user_set.add_user!(user_uuid: dummy_uuid_1)
      expect(socure_user_set.count).to eq(1)
    end

    it 'does not add duplicates' do
      socure_user_set.add_user!(user_uuid: dummy_uuid_1)
      expect(socure_user_set.count).to eq(1)
      socure_user_set.add_user!(user_uuid: dummy_uuid_1)
      expect(socure_user_set.count).to eq(1)
    end

    it 'does not allow more than doc_auth_socure_max_allowed_users to be added to set' do
      socure_user_set.add_user!(user_uuid: dummy_uuid_1)
      expect(socure_user_set.count).to eq(1)
      socure_user_set.add_user!(user_uuid: dummy_uuid_2)
      expect(socure_user_set.count).to eq(2)
      socure_user_set.add_user!(user_uuid: dummy_uuid_3)
      expect(socure_user_set.count).to eq(2)
    end
  end

  describe '#count' do
    before do
      allow(IdentityConfig.store).to receive(:doc_auth_socure_max_allowed_users).and_return(10)
    end
    it 'count is zero when there are no users in the redis store' do
      expect(socure_user_set.count).to eq(0)
    end

    it 'gives the user count' do
      10.times.each_with_index do |index|
        socure_user_set.add_user!(user_uuid: "000#{index}")
      end

      expect(socure_user_set.count).to eq(10)
    end
  end
end
