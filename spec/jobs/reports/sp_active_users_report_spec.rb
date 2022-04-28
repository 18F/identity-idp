require 'rails_helper'

describe Reports::SpActiveUsersReport do
  subject { described_class.new }

  let(:issuer) { 'foo' }
  let(:issuer2) { 'foo2' }
  let(:app_id) { 'app' }

  it 'is empty' do
    expect(subject.perform(Time.zone.today)).to eq('[]')
  end

  it 'returns total active user counts per sp broken down by ial1 and ial2' do
    job_date = Date.new(2022, 1, 1)
    authenticated_time = job_date.noon
    ServiceProvider.create(issuer: issuer, friendly_name: issuer, app_id: 'app')
    ServiceProviderIdentity.create(
      user_id: 1, service_provider: issuer, uuid: 'foo1',
      last_ial1_authenticated_at: authenticated_time, last_ial2_authenticated_at: authenticated_time
    )
    ServiceProviderIdentity.create(
      user_id: 2, service_provider: issuer, uuid: 'foo2',
      last_ial1_authenticated_at: authenticated_time
    )
    ServiceProviderIdentity.create(
      user_id: 3, service_provider: issuer, uuid: 'foo3',
      last_ial2_authenticated_at: authenticated_time
    )
    ServiceProviderIdentity.create(
      user_id: 4, service_provider: issuer, uuid: 'foo4',
      last_ial2_authenticated_at: authenticated_time
    )
    result = [{ issuer: issuer, app_id: app_id, total_ial1_active: 2,
                total_ial2_active: 3 }].to_json

    expect(subject.perform(Time.zone.today)).to eq(result)
  end

  it 'when Oct 1, returns total active user counts per sp by ial1 and ial2 for last fiscal year' do
    job_date = Date.new(2020, 10, 1)
    beginning_of_last_fiscal_year = job_date.change(year: 2019, month: 10, day: 1).beginning_of_day
    end_of_last_fiscal_year = job_date.change(year: 2020, month: 9, day: 30).end_of_day
    middle_of_last_fiscal_year = job_date.change(year: 2020, month: 1, day: 31).end_of_day

    beginning_of_current_fiscal_year = job_date.beginning_of_day
    current_fiscal_year = job_date.change(hour: 12, minute: 30)

    ServiceProvider.create(issuer: issuer, friendly_name: issuer, app_id: 'app')
    ServiceProviderIdentity.create(
      user_id: 1, service_provider: issuer, uuid: 'foo1',
      last_ial1_authenticated_at: beginning_of_last_fiscal_year,
      last_ial2_authenticated_at: beginning_of_last_fiscal_year
    )
    ServiceProviderIdentity.create(
      user_id: 2, service_provider: issuer, uuid: 'foo2',
      last_ial1_authenticated_at: end_of_last_fiscal_year,
      last_ial2_authenticated_at: end_of_last_fiscal_year
    )
    ServiceProviderIdentity.create(
      user_id: 3, service_provider: issuer, uuid: 'foo3',
      last_ial2_authenticated_at: middle_of_last_fiscal_year
    )
    ServiceProviderIdentity.create(
      user_id: 4, service_provider: issuer, uuid: 'foo4',
      last_ial2_authenticated_at: beginning_of_current_fiscal_year
    )

    ServiceProviderIdentity.create(
      user_id: 5, service_provider: issuer, uuid: 'foo5',
      last_ial2_authenticated_at: current_fiscal_year
    )

    result = [{ issuer: issuer, app_id: app_id, total_ial1_active: 2,
                total_ial2_active: 3 }].to_json

    expect(subject.perform(job_date)).to eq(result)
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
