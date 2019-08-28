require 'rails_helper'

describe JobRunner::HealthChecker do
  before do
    configurations = []
    configurations << JobRunner::JobConfiguration.new(
      name: 'test job 1',
      interval: 5 * 60, # 5 minutes
      timeout: 60,
      callback: -> { 'test job 1 result' },
      failures_before_alarm: 3,
    )
    configurations << JobRunner::JobConfiguration.new(
      name: 'test job 2',
      interval: 60 * 60, # hourly
      timeout: 60 * 30,
      callback: -> { 'test job 2 result' },
    )
    allow(JobRunner::Runner).to receive(:configurations).and_return(configurations)
  end

  context 'when all of the jobs have run as scheduled' do
    it 'returns a healthy summary' do
      create(:job_run, job_name: 'test job 1', created_at: 14.minutes.ago)
      create(:job_run, job_name: 'test job 2', created_at: 20.minutes.ago)

      expected_summary = { healthy: true, result: { 'test job 1' => true, 'test job 2' => true } }

      result = described_class.check

      expect(result.healthy?).to eq(true)
      expect(result.to_h).to eq(expected_summary)
      expect(result.as_json).to eq(expected_summary.as_json)
    end
  end

  context 'when there is a job that has not run' do
    it 'returns an unhealthy summary' do
      create(:job_run, job_name: 'test job 1', created_at: 16.minutes.ago)
      create(:job_run, job_name: 'test job 2', created_at: 20.minutes.ago)

      expected_summary = { healthy: false, result: { 'test job 1' => false, 'test job 2' => true } }

      result = described_class.check

      expect(result.healthy?).to eq(false)
      expect(result.to_h).to eq(expected_summary)
      expect(result.as_json).to eq(expected_summary.as_json)
    end
  end
end
