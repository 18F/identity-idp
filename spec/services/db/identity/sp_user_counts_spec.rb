require 'rails_helper'

RSpec.describe Db::Identity::SpUserCounts do
  subject { described_class }

  describe '.by_issuer' do
    let(:issuer) { 'foo' }
    let(:app_id) { 'app_id' }
    let(:issuer2) { 'foo2' }
    let(:app_id2) { 'app_id2' }

    it 'is empty' do
      expect(subject.by_issuer.size).to eq(0)
    end

    it 'returns the total user counts per sp broken down by ial1 and ial2' do
      ServiceProvider.create(issuer:, friendly_name: issuer, app_id:)
      ServiceProvider.create(issuer: issuer2, friendly_name: issuer2, app_id: app_id2)
      ServiceProviderIdentity.create(user_id: 1, service_provider: issuer, uuid: 'foo1')
      ServiceProviderIdentity.create(user_id: 2, service_provider: issuer, uuid: 'foo2')
      ServiceProviderIdentity.create(
        user_id: 3, service_provider: issuer, uuid: 'foo3',
        verified_at: Time.zone.now
      )
      ServiceProviderIdentity.create(
        user_id: 4, service_provider: issuer2, uuid: 'foo4',
        verified_at: Time.zone.now
      )
      result = { issuer:, total: 3, ial1_total: 2, ial2_total: 1, app_id: }.to_json
      result2 = { issuer: issuer2, total: 1, ial1_total: 0, ial2_total: 1, app_id: app_id2 }.to_json

      tuples = subject.by_issuer
      expect(tuples.size).to eq(2)
      expect(tuples[0].to_json).to eq(result)
      expect(tuples[1].to_json).to eq(result2)
    end
  end

  describe '.overall' do
    let(:sp1) { create(:service_provider) }
    let(:sp2) { create(:service_provider) }

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
      create(:service_provider_identity, user_id: 1, service_provider_record: sp1)
      create(:service_provider_identity, :verified, user_id: 1, service_provider_record: sp2)

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
