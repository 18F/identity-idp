require 'rails_helper'

RSpec.describe Db::Identity::SpActiveUserCounts do
  subject { described_class }

  let(:fiscal_start_date) { 1.year.ago }
  let(:app_id1) { 'app_id1' }
  let(:app_id2) { 'app_id2' }
  let(:sp1) { create(:service_provider, app_id: app_id1) }
  let(:sp2) { create(:service_provider, app_id: app_id2) }
  let(:issuer) { sp1.issuer }
  let(:issuer2) { sp2.issuer }
  let(:now) { Time.zone.now }
  let(:users) { create_list(:user, 4) }

  describe '.by_issuer' do
    it 'is empty' do
      expect(subject.by_issuer(fiscal_start_date).size).to eq(0)
    end

    it 'returns total active user counts per sp broken down by ial1 and ial2 for ial1 only sps' do
      ServiceProviderIdentity.create(
        user_id: users[0].id, service_provider: issuer, uuid: 'foo1',
        last_ial1_authenticated_at: now
      )
      ServiceProviderIdentity.create(
        user_id: users[1].id, service_provider: issuer, uuid: 'foo2',
        last_ial1_authenticated_at: now
      )
      ServiceProviderIdentity.create(
        user_id: users[2].id, service_provider: issuer2, uuid: 'foo3',
        last_ial1_authenticated_at: now
      )
      result = { issuer: issuer,
                 app_id: app_id1,
                 total_ial1_active: 2,
                 total_ial2_active: 0 }.with_indifferent_access
      result2 = { issuer: issuer2,
                  app_id: app_id2,
                  total_ial1_active: 1,
                  total_ial2_active: 0 }.with_indifferent_access

      tuples = subject.by_issuer(fiscal_start_date)
      expect(tuples.size).to eq(2)
      expect(tuples).to include(result)
      expect(tuples).to include(result2)
    end

    it 'returns total active user counts per sp broken down by ial1 and ial2 for ial2 only sps' do
      ServiceProviderIdentity.create(
        user_id: users[0].id, service_provider: issuer, uuid: 'foo1',
        last_ial2_authenticated_at: now
      )
      ServiceProviderIdentity.create(
        user_id: users[1].id, service_provider: issuer, uuid: 'foo2',
        last_ial2_authenticated_at: now
      )
      ServiceProviderIdentity.create(
        user_id: users[2].id, service_provider: issuer2, uuid: 'foo3',
        last_ial2_authenticated_at: now
      )
      result = { issuer: issuer,
                 app_id: app_id1,
                 total_ial1_active: 0,
                 total_ial2_active: 2 }.with_indifferent_access
      result2 = { issuer: issuer2,
                  app_id: app_id2,
                  total_ial1_active: 0,
                  total_ial2_active: 1 }.with_indifferent_access

      tuples = subject.by_issuer(fiscal_start_date)
      expect(tuples.size).to eq(2)
      expect(tuples).to include(result)
      expect(tuples).to include(result2)
    end

    it 'returns total active user counts per sp broken down by ial1 and ial2 for ial1 ial2 sps' do
      ServiceProviderIdentity.create(
        user_id: users[0].id, service_provider: issuer, uuid: 'foo1',
        last_ial1_authenticated_at: now, last_ial2_authenticated_at: now
      )
      ServiceProviderIdentity.create(
        user_id: users[1].id, service_provider: issuer, uuid: 'foo2',
        last_ial1_authenticated_at: now
      )
      ServiceProviderIdentity.create(
        user_id: users[2].id, service_provider: issuer2, uuid: 'foo3',
        last_ial1_authenticated_at: now, last_ial2_authenticated_at: now
      )
      ServiceProviderIdentity.create(
        user_id: users[3].id, service_provider: issuer2, uuid: 'foo4',
        last_ial2_authenticated_at: now
      )
      result = { issuer: issuer,
                 app_id: app_id1,
                 total_ial1_active: 1,
                 total_ial2_active: 1 }.with_indifferent_access
      result2 = { issuer: issuer2,
                  app_id: app_id2,
                  total_ial1_active: 0,
                  total_ial2_active: 2 }.with_indifferent_access

      tuples = subject.by_issuer(fiscal_start_date)
      expect(tuples.size).to eq(2)
      expect(tuples).to include(result)
      expect(tuples).to include(result2)
    end
  end

  describe '.overall' do
    it 'has placeholder rows with no data' do
      result = subject.overall(fiscal_start_date)

      expect(result.size).to eq(1)
      expect(result.first).to eq(
        'issuer' => nil,
        'app_id' => nil,
        'total_ial1_active' => 0,
        'total_ial2_active' => 0,
      )
    end

    it 'counts the numbers of users that were ial1 active and ial2 active' do
      # ial1 and ial2, counts as ial2
      create(
        :service_provider_identity,
        user_id: users[0].id,
        service_provider_record: sp1,
        last_ial1_authenticated_at: now,
      )
      create(
        :service_provider_identity,
        user_id: users[0].id,
        service_provider_record: sp2,
        last_ial2_authenticated_at: now,
      )

      # ial1 only, counts as ial1
      create(
        :service_provider_identity,
        user_id: users[1].id,
        service_provider_record: sp1,
        last_ial1_authenticated_at: now,
      )

      result = subject.overall(fiscal_start_date)

      expect(result.size).to eq(1)
      expect(result.first).to eq(
        'issuer' => nil,
        'app_id' => nil,
        'total_ial1_active' => 1,
        'total_ial2_active' => 1,
      )
    end
  end

  describe '.overall_apg' do
    let(:sp3) { create(:service_provider) }

    it 'adds up overall usage, duplicating users who go to multiple SPs' do
      [sp1, sp2, sp3].each do |sp|
        create(
          :service_provider_identity,
          user_id: users[0].id,
          service_provider_record: sp,
          last_ial1_authenticated_at: now,
        )
      end

      result = subject.overall_apg(fiscal_start_date)

      expect(result.size).to eq(1)
      expect(result.first).to eq(
        'issuer' => nil,
        'app_id' => nil,
        'total_ial1_active' => 3,
        'total_ial2_active' => 0,
      )
    end
  end
end
