require 'rails_helper'

describe Reports::IdentityReuseReport do
  subject { described_class.new }

  let(:issuer) { 'foo' }
  let(:issuer2) { 'foo2' }
  let(:app_id) { 'app_id' }

  it 'is returns zeros when no identities' do
    result = {
      total_ial1_identity_counts: 0,
      total_unique_ial1_identity_counts: 0,
      total_ial2_identity_counts: 0,
      total_unique_ial2_identity_counts: 0,
    }.to_json

    expect(subject.perform(Time.zone.today)).to eq(result)
  end

  it 'logs to analytics' do
    ServiceProvider.create(issuer: issuer, friendly_name: issuer, app_id: app_id)
    ServiceProviderIdentity.create(user_id: 1, service_provider: issuer, uuid: 'foo2', ial: 1)
    ServiceProviderIdentity.create(user_id: 2, service_provider: issuer, uuid: 'foo3', ial: 1)
    ServiceProviderIdentity.create(user_id: 3, service_provider: issuer, uuid: 'foo4', ial: 2)
    freeze_time do
      timestamp = Time.zone.now.iso8601
      expect(subject).to receive(:write_hash_to_reports_log).with(
        total_ial1_identity_counts: 2,
        total_unique_ial1_identity_counts: 2,
        total_ial2_identity_counts: 1,
        total_unique_ial2_identity_counts: 1,
        name: 'Report Identity Reuse Counts',
        time: timestamp,
      )
      subject.perform(Time.zone.today)
    end
  end

  it 'returns the reuse counts when ial 1 is reused' do
    ServiceProvider.create(issuer: issuer, friendly_name: issuer, app_id: app_id)
    ServiceProviderIdentity.create(user_id: 1, service_provider: issuer, uuid: 'foo1', ial: 1)
    ServiceProviderIdentity.create(user_id: 1, service_provider: issuer2, uuid: 'foo2', ial: 1)

    expect(subject.perform(Time.zone.today)).to eq(
      {
        total_ial1_identity_counts: 2,
        total_unique_ial1_identity_counts: 1,
        total_ial2_identity_counts: 0,
        total_unique_ial2_identity_counts: 0,
      }.to_json,
    )
  end

  it 'returns the reuse counts when ial 2 is reused' do
    ServiceProvider.create(issuer: issuer, friendly_name: issuer, app_id: app_id)
    ServiceProviderIdentity.create(user_id: 1, service_provider: issuer, uuid: 'foo1', ial: 2)
    ServiceProviderIdentity.create(user_id: 1, service_provider: issuer2, uuid: 'foo2', ial: 2)

    expect(subject.perform(Time.zone.today)).to eq(
      {
        total_ial1_identity_counts: 0,
        total_unique_ial1_identity_counts: 0,
        total_ial2_identity_counts: 2,
        total_unique_ial2_identity_counts: 1,
      }.to_json,
    )
  end

  describe '#good_job_concurrency_key' do
    let(:date) { Time.zone.today }

    it 'is the job name and the date' do
      job = described_class.new(date)
      expect(job.good_job_concurrency_key).
        to eq("#{described_class::REPORT_NAME}-#{date}")
    end
  end
end
