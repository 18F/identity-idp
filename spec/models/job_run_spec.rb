require 'rails_helper'

describe JobRun do
  describe '.find_recent_errors' do
    it 'returns jobs with recent errors' do
      since = 2.days.ago
      recent_jobs_with_errors = create_list(
        :job_run, 5,
        error: 'This is recent',
        created_at: 1.day.ago
      )

      # Create some old jobs with errors that should not appear
      create_list(:job_run, 5, error: 'This is recent', created_at: 3.days.ago)
      # Create jobs without errors that should not appear
      create_list(:job_run, 5)

      results = JobRun.find_recent_errors(since)
      expect(results).to eq(recent_jobs_with_errors)
    end
  end

  describe '.clean_up_timeouts' do
    it 'marks old unfinished jobs as timed out' do
      finished_job = create(:job_run, finish_time: 1.minute.ago, result: 'Ok')
      errored_job = create(:job_run, finish_time: 1.minute.ago, error: 'Sad')
      running_job = create(:job_run, created_at: 1.minute.ago)
      timedout_job = create(:job_run, created_at: 3.minutes.ago)
      timedout_job_with_different_nane = create(
        :job_run,
        job_name: 'Diffy',
        created_at: 3.minutes.ago,
      )

      expect(NewRelic::Agent).to receive(:notice_error).with(/JobRun timed out/)

      JobRun.clean_up_timeouts(job_name: timedout_job.job_name, timeout_threshold: 2.minutes.ago)

      expect(timedout_job.reload.error).to eq('Timeout')
      expect(finished_job).to eq(JobRun.find(finished_job.id))
      expect(errored_job).to eq(JobRun.find(errored_job.id))
      expect(running_job).to eq(JobRun.find(running_job.id))
      expect(timedout_job_with_different_nane).to eq(
        JobRun.find(timedout_job_with_different_nane.id),
      )
    end
  end
end
