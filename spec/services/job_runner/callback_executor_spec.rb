require 'rails_helper'

describe JobRunner::CallbackExecutor do
  describe '#execute_job' do
    let(:job_run) { create(:job_run) }

    subject { described_class.new(job_run: job_run, job_configuration: job_configuration) }

    context 'when the job succeeds' do
      let(:job_configuration) do
        JobRunner::JobConfiguration.new(
          name: 'Send GPO letter',
          interval: 5 * 60,
          timeout: 60,
          callback: -> { 'Hello!' },
        )
      end

      it 'saves the result' do
        subject.execute_job

        expect(job_run.reload.result).to eq('Hello!')
        expect(job_run.error).to eq(nil)
        expect(job_run.finish_time).to be_within(1.second).of(Time.zone.now)
      end
    end

    context 'when the job fails' do
      let(:error) do
        runtime_error = RuntimeError.new('test')
        allow(runtime_error).to receive(:inspect).and_return('test error inspected')
        runtime_error
      end
      let(:job_configuration) do
        JobRunner::JobConfiguration.new(
          name: 'Send GPO letter',
          interval: 5 * 60,
          timeout: 60,
          callback: -> { raise(error) },
        )
      end

      it 'saves the error' do
        subject.execute_job

        expect(job_run.reload.result).to eq(nil)
        expect(job_run.error).to eq('test error inspected')
        expect(job_run.finish_time).to be_within(1.second).of(Time.zone.now)
      end

      it 'reports the error to NewRelic' do
        expect(NewRelic::Agent).to receive(:notice_error).with(error)

        subject.execute_job
      end
    end
  end
end
