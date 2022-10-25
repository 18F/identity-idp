require 'rails_helper'

describe Reports::SpUserCountsReport do
  subject { described_class.new }

  let(:issuer) { 'foo' }
  let(:app_id) { 'app_id' }

  it 'is empty' do
    expect(subject.perform(Time.zone.today)).to eq('[]')
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
    ServiceProvider.create(issuer: issuer, friendly_name: issuer, app_id: app_id)
    ServiceProviderIdentity.create(user_id: 1, service_provider: issuer, uuid: 'foo1')
    ServiceProviderIdentity.create(user_id: 2, service_provider: issuer, uuid: 'foo2')
    ServiceProviderIdentity.create(
      user_id: 3, service_provider: issuer, uuid: 'foo3',
      verified_at: Time.zone.now
    )
    result = [{ issuer: issuer, total: 3, ial1_total: 2, ial2_total: 1, app_id: app_id }].to_json

    expect(subject.perform(Time.zone.today)).to eq(result)
  end
end
