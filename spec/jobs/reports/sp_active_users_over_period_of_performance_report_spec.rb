require 'rails_helper'

describe Reports::SpActiveUsersOverPeriodOfPerformanceReport do
  subject { described_class.new }

  let(:issuer) { 'foo' }
  let(:issuer2) { 'foo2' }
  let(:app_id) { 'app' }

  it 'is empty' do
    expect(subject.perform(Time.zone.today)).to eq('[]')
  end

  it 'returns total active user counts per sp broken down by ial1 and ial2' do
    now = Time.zone.now
    service_provider = ServiceProvider.create(
      issuer: issuer,
      friendly_name: issuer,
      app_id: app_id,
      iaa_start_date: now - 6.months,
      iaa_end_date: now + 6.months,
    )
    ServiceProviderIdentity.create(
      user_id: 1, service_provider: issuer, uuid: 'foo1',
      last_ial1_authenticated_at: now, last_ial2_authenticated_at: now
    )
    ServiceProviderIdentity.create(
      user_id: 2, service_provider: issuer, uuid: 'foo2',
      last_ial1_authenticated_at: now
    )
    ServiceProviderIdentity.create(
      user_id: 3, service_provider: issuer, uuid: 'foo3',
      last_ial2_authenticated_at: now
    )
    ServiceProviderIdentity.create(
      user_id: 4, service_provider: issuer, uuid: 'foo4',
      last_ial2_authenticated_at: now
    )

    result = subject.perform(Time.zone.today)

    expect(JSON.parse(result, symbolize_names: true)).to eq(
      [{
        issuer: issuer,
        app_id: app_id,
        iaa: service_provider.iaa,
        total_ial1_active: 2,
        total_ial2_active: 3,
        iaa_start_date: service_provider.iaa_start_date.to_s,
        iaa_end_date: service_provider.iaa_end_date.to_s,
      }],
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
