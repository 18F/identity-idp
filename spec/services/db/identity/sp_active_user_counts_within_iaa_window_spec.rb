require 'rails_helper'

describe Db::Identity::SpActiveUserCountsWithinIaaWindow do
  subject { described_class }

  it 'is empty' do
    expect(subject.call.ntuples).to eq(0)
  end

  context 'with data' do
    let(:service_provider_no_start_end) do
      create(
        :service_provider,
        issuer: 'issuer1',
        iaa_start_date: nil,
        iaa_end_date: nil,
      )
    end

    let(:service_provider_april_to_april) do
      create(
        :service_provider,
        issuer: 'issuer2',
        iaa: 'iaa_abcdef',
        iaa_start_date: Date.new(2021, 4, 1),
        iaa_end_date: Date.new(2022, 4, 1),
      )
    end

    let(:service_provider_september_to_september) do
      create(
        :service_provider,
        issuer: 'issuer3',
        iaa_start_date: Date.new(2021, 9, 1),
        iaa_end_date: Date.new(2022, 9, 1),
      )
    end

    let(:inside_april_to_april) { Date.new(2021, 5, 1) }
    let(:inside_september_to_september) { Date.new(2021, 10, 1) }
    let(:outside_iaas) { Date.new(2020, 1, 1) }

    before do
      # SP without start/end dates, one IAL 1 login (skipped)
      create(
        :service_provider_identity,
        service_provider_record: service_provider_no_start_end,
        last_ial1_authenticated_at: inside_april_to_april,
      )

      # April-April SP
      # one IAL1 login within IAA window
      create(
        :service_provider_identity,
        service_provider_record: service_provider_april_to_april,
        last_ial1_authenticated_at: inside_april_to_april,
      )
      # one IAL1 login outside IAA window (skipped)
      create(
        :service_provider_identity,
        service_provider_record: service_provider_april_to_april,
        last_ial1_authenticated_at: outside_iaas,
      )

      # September-September SP
      # has two IAL1 logins within IAA window
      2.times do
        create(
          :service_provider_identity,
          service_provider_record: service_provider_september_to_september,
          last_ial1_authenticated_at: inside_september_to_september,
        )
      end
      # has two IAL2 logins within IAA window
      3.times do
        create(
          :service_provider_identity,
          service_provider_record: service_provider_september_to_september,
          last_ial2_authenticated_at: inside_september_to_september,
        )
      end
      # has one IAL2 login outside IAA window (skipped)
      create(
        :service_provider_identity,
        service_provider_record: service_provider_september_to_september,
        last_ial2_authenticated_at: outside_iaas,
      )
    end

    it 'returns active user counts by SP with the IAA start/end, counted by IAL1 level' do
      result = subject.call

      expect(result.ntuples).to eq(2)

      april = result.first
      expect(april.symbolize_keys).to eq(
        issuer: service_provider_april_to_april.issuer,
        app_id: service_provider_april_to_april.app_id,
        iaa: service_provider_april_to_april.iaa,
        total_ial1_active: 1,
        total_ial2_active: 0,
        iaa_start_date: service_provider_april_to_april.iaa_start_date.to_s,
        iaa_end_date: service_provider_april_to_april.iaa_end_date.to_s,
      )

      september = result.to_a.last
      expect(september.symbolize_keys).to eq(
        issuer: service_provider_september_to_september.issuer,
        app_id: service_provider_september_to_september.app_id,
        iaa: service_provider_september_to_september.iaa,
        total_ial1_active: 2,
        total_ial2_active: 3,
        iaa_start_date: service_provider_september_to_september.iaa_start_date.to_s,
        iaa_end_date: service_provider_september_to_september.iaa_end_date.to_s,
      )
    end
  end
end
