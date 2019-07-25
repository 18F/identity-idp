require 'rails_helper'

describe JobRunner::Runner do
  describe '.configurations' do
    it 'has the GPO letter job' do
      job = JobRunner::Runner.configurations.find { |c| c.name == 'Send GPO letter' }
      expect(job).to be_instance_of(JobRunner::JobConfiguration)
      expect(job.interval).to eq 24 * 60 * 60

      stub = instance_double(UspsConfirmationUploader)
      expect(UspsConfirmationUploader).to receive(:new).and_return(stub)
      expect(stub).to receive(:run).and_return('the GPO test worked')

      expect(job.callback.call).to eq 'the GPO test worked'
    end

    it 'runs the account reset job' do
      job = JobRunner::Runner.configurations.find { |c| c.name == 'Account reset notice' }
      expect(job).to be_instance_of(JobRunner::JobConfiguration)
      expect(job.interval).to eq 300

      service = instance_double(AccountReset::GrantRequestsAndSendEmails)
      expect(AccountReset::GrantRequestsAndSendEmails).to receive(:new).and_return(service)
      expect(service).to receive(:call).and_return('the reset test worked')

      expect(job.callback.call).to eq 'the reset test worked'
    end

    it 'runs the OMB Fitara report job' do
      job = JobRunner::Runner.configurations.find { |c| c.name == 'OMB Fitara report' }
      expect(job).to be_instance_of(JobRunner::JobConfiguration)
      expect(job.interval).to eq 24 * 60 * 60

      expect(Reports::OmbFitaraReport).to receive(:call).and_return('the report test worked')

      expect(job.callback.call).to eq 'the report test worked'
    end
  end
end
