require 'rails_helper'

describe JobRunner::Runner do
  before do
    configurations = []
    configurations << JobRunner::JobConfiguration.new(
      name: 'test job 1',
      interval: 5 * 60,
      timeout: 60,
      callback: -> { 'test job 1 result' },
    )
    configurations << JobRunner::JobConfiguration.new(
      name: 'test job 2',
      interval: 60 * 60,
      timeout: 60 * 30,
      callback: -> { 'test job 2 result' },
    )
    allow(described_class).to receive(:configurations).and_return(configurations)
  end

  describe '#run' do
    it 'runs the jobs in the configuration' do
      subject.run

      expect(JobRun.count).to eq(2)

      first_job = JobRun.find_by(job_name: 'test job 1')
      expect(first_job.result).to eq('test job 1 result')

      second_job = JobRun.find_by(job_name: 'test job 2')
      expect(second_job.result).to eq('test job 2 result')
    end

    context 'when their are jobs that are not due to run' do
      it 'only runs the jobs that are due to run' do
        previous_job_start = 20.minutes.ago
        create(:job_run, job_name: 'test job 2', created_at: previous_job_start)

        subject.run

        expect(JobRun.count).to eq(2)

        first_job = JobRun.find_by(job_name: 'test job 1')
        expect(first_job.result).to eq('test job 1 result')

        second_job = JobRun.find_by(job_name: 'test job 2')
        expect(second_job.created_at).to be_within(1.second).of(previous_job_start)
      end
    end

    context 'when their are timed out jobs' do
      it 'cleans up the timed out jobs' do
        timed_out_job_start = 120.minutes.ago
        create(:job_run, job_name: 'test job 2', created_at: timed_out_job_start)

        subject.run

        expect(JobRun.count).to eq(3)

        first_job = JobRun.find_by(job_name: 'test job 1')
        expect(first_job.result).to eq('test job 1 result')

        timed_out_job, second_job = JobRun.where(job_name: 'test job 2').
                                    order(created_at: :asc).to_a

        expect(timed_out_job.result).to eq(nil)
        expect(timed_out_job.finish_time).to eq(nil)
        expect(timed_out_job.error).to eq('Timeout')
        expect(timed_out_job.created_at).to be_within(1.second).of(timed_out_job_start)

        expect(second_job.result).to eq('test job 2 result')
      end
    end
  end
end
