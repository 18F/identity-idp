require 'rails_helper'

describe JobRun do
  describe '.find_recent_errors' do
    it 'returns jobs with recent errors' do
      since = 2.days.ago
      recent_jobs_with_errors = create_list(:job_run, 5, error: 'This is recent', created_at: 1.day.ago)

      # Create some old jobs with errors that should not appear
      create_list(:job_run, 5, error: 'This is recent', created_at: 3.days.ago)
      # Create jobs without errors that should not appear
      create_list(:job_run, 5)

      results = JobRun.find_recent_errors(since)
      expect(results).to eq(recent_jobs_with_errors)
    end
  end

  describe '.find_recent_errors' do
    it 'returns jobs with recent errors' do
      since = 2.days.ago
      recent_jobs_with_errors = create_list(:job_run, 5, error: 'This is recent', created_at: 1.day.ago)

      # Create some old jobs with errors that should not appear
      create_list(:job_run, 5, error: 'This is recent', created_at: 3.days.ago)
      # Create jobs without errors that should not appear
      create_list(:job_run, 5)

      results = JobRun.find_recent_errors(since)
      expect(results).to eq(recent_jobs_with_errors)
    end
  end

  it 'mark as timed out with bad argument' do
    job_run = JobRun.new
    job_run.job_name = 'Test job timing out'
    job_run.result = 'fake result'
    job_run.save!

    expect { job_run.mark_as_timed_out }.to raise_error(ArgumentError)
  end

  it 'mark as timed out with good argument' do
    job_run = JobRun.new
    job_run.job_name = 'Test job timing out'
    job_run.save!
    job_run.mark_as_timed_out

    expect(job_run.error).to have_attributes(upcase: 'TIMEOUT')
  end
end
