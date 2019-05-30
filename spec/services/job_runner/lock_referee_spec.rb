require 'rails_helper'

describe JobRunner::LockReferee do
  describe '#acquire_lock_and_run_callback_if_needed' do
    let(:job_configuration) do
      JobRunner::JobConfiguration.new(
        name: 'Send GPO letter',
        interval: 5 * 60,
        timeout: 60,
        callback: -> { 'Hello!' },
      )
    end

    subject { described_class.new(job_configuration) }

    context 'when a job has run recently' do
      let!(:job_run) { create(:job_run, created_at: 1.minute.ago) }

      it 'does nothing' do
        # It should not try to acquire a lock
        expect(JobRun).to_not receive(:with_lock)

        subject.acquire_lock_and_run_callback_if_needed

        # It should not modify the existing job or create a new one
        expect(job_run).to eq(JobRun.find(job_run.id))
        expect(JobRun.count).to eq(1)
      end
    end

    context 'when another thread wins the race and acquires a lock' do
      it 'does not run a job' do
        job_run = nil
        expect(JobRun).to receive(:with_lock) do |&block|
          # Simulate another job getting the lock and creating a job run
          job_run = create(:job_run, created_at: 1.minute.ago)
          block.call
        end

        subject.acquire_lock_and_run_callback_if_needed

        # It should not modify the existing job or create a new one
        expect(job_run).to eq(JobRun.find(job_run.id))
        expect(JobRun.count).to eq(1)
      end
    end

    context 'when this thread wins the race' do
      it 'creates a JobRun and runs the callback' do
        # It should try to acquire a lock
        expect(JobRun).to receive(:with_lock).and_call_original

        subject.acquire_lock_and_run_callback_if_needed

        # It should have created a job with the result from the callback
        expect(JobRun.count).to eq(1)
        expect(JobRun.first.result).to eq('Hello!')
      end
    end
  end
end
