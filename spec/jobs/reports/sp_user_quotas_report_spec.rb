require 'rails_helper'

describe Reports::SpUserQuotasReport do
  subject { described_class.new }

  let(:issuer) { 'foo' }
  let(:app_id) { 'app_id' }

  it 'is empty' do
    expect(subject.perform(Time.zone.today)).to eq('[]')
  end

  it 'runs correctly if the current month is before the fiscal start month of October' do
    expect_report_to_run_correctly_for_fiscal_start_year_month_day(2019, 9, 1)
  end

  it 'runs correctly if the current month is after the fiscal start month of October' do
    expect_report_to_run_correctly_for_fiscal_start_year_month_day(2019, 11, 1)
  end

  def expect_report_to_run_correctly_for_fiscal_start_year_month_day(year, month, day)
    ServiceProvider.create(issuer: issuer, friendly_name: issuer, app_id: app_id)
    ServiceProviderIdentity.create(user_id: 1, service_provider: issuer, uuid: 'foo1')
    ServiceProviderIdentity.create(user_id: 2, service_provider: issuer, uuid: 'foo2')
    ServiceProviderIdentity.create(
      user_id: 3, service_provider: issuer, uuid: 'foo3',
      verified_at: Time.zone.now
    )
    results = [{ issuer: issuer, app_id: app_id, ial2_total: 1, percent_ial2_quota: 0 }].to_json

    travel_to(Date.new(year, month, day)) do
      expect(subject.perform(Time.zone.today)).to eq(results)
    end
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
