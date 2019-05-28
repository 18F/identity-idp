require 'rails_helper'

describe JobRunner::JobRunNeededResolver do
  let(:job_configuration) do
    JobRunner::JobConfiguration.new(
      name: 'Send GPO letter',
      interval: 5 * 60,
      timeout: 60,
      callback: -> { 'Hello!' },
    )
  end

  subject { described_class.new(job_configuration) }

  describe '#new_job_needs_to_run?' do
    context 'no jobs have been run ever' do
      it { expect(subject.new_job_needs_to_run?).to eq(true) }
    end

    context 'a job has been run within the interval' do
      let!(:job_run) { create(:job_run, created_at: 4.minutes.ago) }

      it { expect(subject.new_job_needs_to_run?).to eq(false) }
    end

    context 'a job has been run outside the interval' do
      let!(:job_run) { create(:job_run, created_at: 6.minutes.ago) }

      it { expect(subject.new_job_needs_to_run?).to eq(true) }
    end

    context 'a job with a different name has been run within the interval' do
      let!(:job_run) { create(:job_run, created_at: 4.minutes.ago, job_name: 'different job') }

      it { expect(subject.new_job_needs_to_run?).to eq(true) }
    end
  end
end
