require 'rails_helper'

RSpec.describe Reports::SpUserCountsReport do
  subject { described_class.new }

  let(:issuer) { 'foo' }
  let(:app_id) { 'app_id' }

  it 'is empty' do
    report = JSON.parse(subject.perform(Time.zone.today), symbolize_names: true)

    expect(report).to eq(
      [
        {
          issuer: 'LOGIN_ALL',
          total: 0,
          ial1_total: 0,
          ial2_total: 0,
          app_id: nil,
        }
      ],
    )
  end

  it 'logs to analytics' do
    ServiceProvider.create(issuer: issuer, friendly_name: issuer, app_id: app_id)
    ServiceProviderIdentity.create(user_id: 1, service_provider: issuer, uuid: 'foo2', ial: 1)
    ServiceProviderIdentity.create(user_id: 2, service_provider: issuer, uuid: 'foo3', ial: 1)
    ServiceProviderIdentity.create(user_id: 3, service_provider: issuer, uuid: 'foo4', ial: 2)
    freeze_time do
      timestamp = Time.zone.now.iso8601
      expect(subject).to receive(:write_hash_to_reports_log).with(
        {
          app_id: app_id,
          ial1_user_total: 3,
          ial2_user_total: 0,
          issuer: issuer,
          name: 'Report SP User Counts',
          time: timestamp,
          user_total: 3,
        },
      )
      expect(subject).to receive(:write_hash_to_reports_log).with(
        {
          app_id: '',
          ial1_user_total: 3,
          ial2_user_total: 0,
          issuer: 'LOGIN_ALL',
          name: 'Report SP User Counts',
          time: timestamp,
          user_total: 3,
        },
      )
      expect(subject).to receive(:write_hash_to_reports_log).with(
        {
          name: 'Report Registered Users Count',
          time: timestamp,
          count: 0,
        },
      )
      expect(subject).to receive(:write_hash_to_reports_log).with(
        {
          name: 'Report IAL1 Users Linked to SPs Count',
          time: timestamp,
          count: 2,
        },
      )
      expect(subject).to receive(:write_hash_to_reports_log).with(
        {
          name: 'Report IAL2 Users Linked to SPs Count',
          time: timestamp,
          count: 1,
        },
      )
      subject.perform(Time.zone.today)
    end
  end

  it 'returns the total user counts per sp broken down by ial1 and ial2' do
    create(:service_provider, issuer: issuer, app_id: app_id)
    create(:service_provider_identity, user_id: 1, service_provider: issuer)
    create(:service_provider_identity, user_id: 2, service_provider: issuer)
    create(
      :service_provider_identity, :verified, user_id: 3, service_provider: issuer,
    )

    issuer2 = 'issuer2'
    app_id2 = 'appid2'
    create(:service_provider, issuer: issuer2, app_id: app_id2)
    create(:service_provider_identity, user_id: 1, service_provider: issuer2)

    expected = [
      {
        issuer: issuer,
        total: 3,
        ial1_total: 2,
        ial2_total: 1,
        app_id: app_id
      },
      {
        issuer: issuer2,
        total: 1,
        ial1_total: 1,
        ial2_total: 0,
        app_id: app_id2,
      },
      {
        issuer: 'LOGIN_ALL',
        total: 3,
        ial1_total: 2,
        ial2_total: 1,
        app_id: nil,
      }
    ]

    result = JSON.parse(subject.perform(Time.zone.today), symbolize_names: true)

    expect(result).to match_array(expected)
  end
end
