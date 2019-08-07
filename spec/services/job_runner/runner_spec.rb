require 'rails_helper'

describe JobRunner::Runner do
  before do
    described_class.clear_configurations
    described_class.add_config JobRunner::JobConfiguration.new(
      name: 'test job 1',
      interval: 5 * 60,
      timeout: 60,
      callback: -> { 'test job 1 result' },
    )
    described_class.add_config JobRunner::JobConfiguration.new(
      name: 'test job 2',
      interval: 60 * 60,
      timeout: 60 * 30,
      callback: -> { 'test job 2 result' },
    )
  end

  describe '.configurations' do
    it 'has the expected configurations' do
      expect(described_class.configurations.length).to eq 2
    end

    it 'freezes the result array' do
      expect { described_class.configurations << 123 }.to raise_error(FrozenError)
    end
  end

  describe '.disabled_jobs' do
    it 'parses disabled job JSON' do
      expect(described_class.disabled_jobs).to eq ['disabled job']
    end
  end

  describe '.add_config' do
    it 'rejects unexpected classes' do
      expect { described_class.add_config 123 }.to raise_error(ArgumentError)
      expect { described_class.add_config 'some job' }.to raise_error(ArgumentError)
    end

    it 'adds a job to the configurations list' do
      config = JobRunner::JobConfiguration.new(
        name: 'test job 3',
        interval: 60 * 60,
        timeout: 60 * 30,
        callback: -> { 'test job 3 result' },
      )

      expect(described_class.configurations.length).to eq 2
      described_class.add_config(config)
      expect(described_class.configurations.length).to eq 3
      expect(described_class.configurations.last).to eq config
    end

    it 'is an alias of add_configuration' do
      expect(described_class.method(:add_config)).to eq described_class.method(:add_configuration)
    end

    it 'ignores disabled jobs' do
      disabled_job = JobRunner::JobConfiguration.new(
        name: 'disabled job',
        interval: 60,
        callback: -> { 'blah' },
      )

      expect(described_class.configurations.length).to eq 2
      expect(described_class.add_config(disabled_job)).to eq false
      expect(described_class.configurations.length).to eq 2
    end
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

    context 'when there are jobs that are not due to run' do
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

    context 'when there are timed out jobs' do
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
