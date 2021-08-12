require 'rails_helper'

describe Reports::UniqueMonthlyAuthsReport do
  subject { described_class.new }

  let(:issuer) { 'foo' }
  let(:app_id) { 'app_id' }
  let(:year_month) { '201901' }

  it 'is empty' do
    expect(subject.perform(Time.zone.today)).to eq('[]')
  end

  it 'returns 1 unique despite the count for the user being 7' do
    ServiceProvider.create(issuer: issuer, friendly_name: issuer, app_id: app_id)
    MonthlySpAuthCount.create(
      issuer: issuer, ial: 1, year_month: '201901', user_id: 2,
      auth_count: 7
    )
    result = [{ issuer: 'foo', year_month: '201901', app_id: app_id, total: 1 }].to_json

    expect(subject.perform(Time.zone.today)).to eq(result)
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
