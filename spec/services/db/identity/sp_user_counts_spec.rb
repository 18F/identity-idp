require 'rails_helper'

RSpec.describe Db::Identity::SpUserCounts do
  subject { described_class }
  let(:proofed_user) { create(:user, :proofed) }
  let(:sp1) { create(:service_provider, :idv, :active) }
  let(:sp2) { create(:service_provider, :idv, :active) }
  let(:user1) { create(:user) }
  let(:user2) { create(:user) }
  let(:user3) { create(:user) }

  describe '.by_issuer' do
    let(:issuer) { sp1.issuer }
    let(:app_id) { sp1.app_id }
    let(:issuer2) { sp2.issuer }
    let(:app_id2) { sp2.app_id }

    it 'is empty' do
      expect(subject.by_issuer.size).to eq(0)
    end

    it 'returns the total user counts per sp broken down by ial1 and ial2' do
      ServiceProviderIdentity.create(user_id: user1.id, service_provider: issuer, ial: 1)
      ServiceProviderIdentity.create(user_id: user2.id, service_provider: issuer, ial: 1)
      ServiceProviderIdentity.create(
        user_id: user3.id, service_provider: issuer, ial: 2,
        verified_at: Time.zone.now
      )
      ServiceProviderIdentity.create(
        user_id: proofed_user.id, service_provider: issuer2, ial: 2,
        verified_at: Time.zone.now
      )

      result = { issuer:, total: 3, ial1_total: 2, ial2_total: 1, app_id: }.with_indifferent_access
      result2 = { issuer: issuer2,
                  total: 1,
                  ial1_total: 0,
                  ial2_total: 1,
                  app_id: app_id2 }.with_indifferent_access

      tuples = subject.by_issuer
      expect(tuples.size).to eq(2)
      expect(tuples).to include(result)
      expect(tuples).to include(result2)
    end
  end

  describe '.overall' do
    it 'has zeroes with no data' do
      result = subject.overall
      expect(result.size).to eq(1)

      expect(result.first).to eq(
        'issuer' => nil,
        'app_id' => nil,
        'total' => 0,
        'ial1_total' => 0,
        'ial2_total' => 0,
      )
    end

    it 'aggregates across all issuers' do
      create(:service_provider_identity, user_id: proofed_user.id, service_provider_record: sp1)
      create(
        :service_provider_identity, :verified, user_id: proofed_user.id,
                                               service_provider_record: sp2
      )

      create(:service_provider_identity, user_id: 2, service_provider_record: sp1)

      result = subject.overall
      expect(result.size).to eq(1)

      expect(result.first).to eq(
        'issuer' => nil,
        'app_id' => nil,
        'total' => 2,
        'ial1_total' => 1,
        'ial2_total' => 1,
      )
    end
  end
end
