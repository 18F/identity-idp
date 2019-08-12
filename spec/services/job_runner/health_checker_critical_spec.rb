require 'rails_helper'

describe JobRunner::HealthCheckerCritical do
  before do
    configurations = []
    configurations << JobRunner::JobConfiguration.new(
      name: 'test job 1',
      interval: 5 * 60, # 5 minutes
      timeout: 60,
      callback: -> { 'test job 1 result' },
      health_critical: true,
    )
    configurations << JobRunner::JobConfiguration.new(
      name: 'normal job',
      interval: 60 * 60,
      timeout: 60 * 30,
      callback: -> { 'normal job result' },
    )
    configurations << JobRunner::JobConfiguration.new(
      name: 'test job 3',
      interval: 60 * 60, # hourly
      timeout: 60,
      callback: -> { 'test job 3 result' },
      health_critical: true,
      failures_before_alarm: 2,
    )
    allow(JobRunner::Runner).to receive(:configurations).and_return(configurations)
  end

  context 'when all of the jobs have run within allowed intervals' do
    it 'returns a healthy summary' do
      create(:job_run, job_name: 'test job 1', created_at: 4.minutes.ago)
      create(:job_run, job_name: 'normal job', created_at: 20.minutes.ago)
      create(:job_run, job_name: 'test job 3', created_at: 119.minutes.ago)

      expected_summary = { healthy: true, result: { 'test job 1' => true, 'test job 3' => true } }

      result = described_class.check

      expect(result.healthy?).to eq(true)
      expect(result.to_h).to eq(expected_summary)
      expect(result.as_json).to eq(expected_summary.as_json)
    end
  end

  context 'when critical jobs are just over allowed threshold' do
    it 'returns an unhealthy summary' do
      create(:job_run, job_name: 'test job 1', created_at: 6.minutes.ago)
      create(:job_run, job_name: 'normal job', created_at: 20.minutes.ago)
      create(:job_run, job_name: 'test job 3', created_at: 121.minutes.ago)

      expected_summary = { healthy: false,
                           result: { 'test job 1' => false, 'test job 3' => false } }

      result = described_class.check

      expect(result.healthy?).to eq(false)
      expect(result.to_h).to eq(expected_summary)
      expect(result.as_json).to eq(expected_summary.as_json)
    end
  end

  context 'when there is a non-critical job that has not run' do
    it 'returns a healthy summary' do
      create(:job_run, job_name: 'test job 1', created_at: 4.minutes.ago)
      create(:job_run, job_name: 'normal job', created_at: 300.minutes.ago)
      create(:job_run, job_name: 'test job 3', created_at: 90.minutes.ago)

      expected_summary = { healthy: true, result: { 'test job 1' => true, 'test job 3' => true } }

      result = described_class.check

      expect(result.healthy?).to eq(true)
      expect(result.to_h).to eq(expected_summary)
      expect(result.as_json).to eq(expected_summary.as_json)
    end
  end
end
