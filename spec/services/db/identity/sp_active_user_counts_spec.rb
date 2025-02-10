require 'rails_helper'

RSpec.describe Db::Identity::SpActiveUserCounts do
  subject { described_class }

  let(:fiscal_start_date) { 1.year.ago }
  let(:issuer) { 'foo' }
  let(:issuer2) { 'foo2' }
  let(:app_id1) { 'app1' }
  let(:app_id2) { 'app2' }
  let(:now) { Time.zone.now }

  describe '.by_issuer' do
    it 'is empty' do
      expect(subject.by_issuer(fiscal_start_date).size).to eq(0)
    end

    it 'returns total active user counts per sp broken down by ial1 and ial2 for ial1 only sps' do
      ServiceProvider.create(issuer: issuer, friendly_name: issuer, app_id: 'app1')
      ServiceProvider.create(issuer: issuer2, friendly_name: issuer2, app_id: 'app2')
      ServiceProviderIdentity.create(
        user_id: 1, service_provider: issuer, uuid: 'foo1',
        last_ial1_authenticated_at: now
      )
      ServiceProviderIdentity.create(
        user_id: 2, service_provider: issuer, uuid: 'foo2',
        last_ial1_authenticated_at: now
      )
      ServiceProviderIdentity.create(
        user_id: 3, service_provider: issuer2, uuid: 'foo3',
        last_ial1_authenticated_at: now
      )
      result = { issuer: issuer,
                 app_id: app_id1,
                 total_ial1_active: 2,
                 total_ial2_active: 0 }.to_json
      result2 = { issuer: issuer2,
                  app_id: app_id2,
                  total_ial1_active: 1,
                  total_ial2_active: 0 }.to_json

      tuples = subject.by_issuer(fiscal_start_date)
      expect(tuples.size).to eq(2)
      expect(tuples[0].to_json).to eq(result)
      expect(tuples[1].to_json).to eq(result2)
    end

    it 'returns total active user counts per sp broken down by ial1 and ial2 for ial2 only sps' do
      ServiceProvider.create(issuer: issuer, friendly_name: issuer, app_id: 'app1')
      ServiceProvider.create(issuer: issuer2, friendly_name: issuer2, app_id: 'app2')
      ServiceProviderIdentity.create(
        user_id: 1, service_provider: issuer, uuid: 'foo1',
        last_ial2_authenticated_at: now
      )
      ServiceProviderIdentity.create(
        user_id: 2, service_provider: issuer, uuid: 'foo2',
        last_ial2_authenticated_at: now
      )
      ServiceProviderIdentity.create(
        user_id: 3, service_provider: issuer2, uuid: 'foo3',
        last_ial2_authenticated_at: now
      )
      result = { issuer: issuer,
                 app_id: app_id1,
                 total_ial1_active: 0,
                 total_ial2_active: 2 }.to_json
      result2 = { issuer: issuer2,
                  app_id: app_id2,
                  total_ial1_active: 0,
                  total_ial2_active: 1 }.to_json

      tuples = subject.by_issuer(fiscal_start_date)
      expect(tuples.size).to eq(2)
      expect(tuples[0].to_json).to eq(result)
      expect(tuples[1].to_json).to eq(result2)
    end

    it 'returns total active user counts per sp broken down by ial1 and ial2 for ial1 ial2 sps' do
      ServiceProvider.create(issuer: issuer, friendly_name: issuer, app_id: 'app1')
      ServiceProvider.create(issuer: issuer2, friendly_name: issuer2, app_id: 'app2')
      ServiceProviderIdentity.create(
        user_id: 1, service_provider: issuer, uuid: 'foo1',
        last_ial1_authenticated_at: now, last_ial2_authenticated_at: now
      )
      ServiceProviderIdentity.create(
        user_id: 2, service_provider: issuer, uuid: 'foo2',
        last_ial1_authenticated_at: now
      )
      ServiceProviderIdentity.create(
        user_id: 3, service_provider: issuer2, uuid: 'foo3',
        last_ial1_authenticated_at: now, last_ial2_authenticated_at: now
      )
      ServiceProviderIdentity.create(
        user_id: 4, service_provider: issuer2, uuid: 'foo4',
        last_ial2_authenticated_at: now
      )
      result = { issuer: issuer,
                 app_id: app_id1,
                 total_ial1_active: 1,
                 total_ial2_active: 1 }.to_json
      result2 = { issuer: issuer2,
                  app_id: app_id2,
                  total_ial1_active: 0,
                  total_ial2_active: 2 }.to_json

      tuples = subject.by_issuer(fiscal_start_date)
      expect(tuples.size).to eq(2)
      expect(tuples[0].to_json).to eq(result)
      expect(tuples[1].to_json).to eq(result2)
    end
  end

  describe '.overall' do
    let(:sp1) { create(:service_provider) }
    let(:sp2) { create(:service_provider) }

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
        user_id: 1,
        service_provider_record: sp1,
        last_ial1_authenticated_at: now,
      )
      create(
        :service_provider_identity,
        user_id: 1,
        service_provider_record: sp2,
        last_ial2_authenticated_at: now,
      )

      # ial1 only, counts as ial1
      create(
        :service_provider_identity,
        user_id: 2,
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
    let(:sp1) { create(:service_provider) }
    let(:sp2) { create(:service_provider) }
    let(:sp3) { create(:service_provider) }

    it 'adds up overall usage, duplicating users who go to multiple SPs' do
      [sp1, sp2, sp3].each do |sp|
        create(
          :service_provider_identity,
          user_id: 1,
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
