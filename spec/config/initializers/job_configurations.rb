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

      result = HolidayService.observed_holiday?(Time.zone.today) ? nil : 'the GPO test worked'
      expect(job.callback.call).to eq result
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

      service = instance_double(Reports::OmbFitaraReport)
      expect(Reports::OmbFitaraReport).to receive(:new).and_return(service)
      expect(service).to receive(:call).and_return('the report test worked')

      expect(job.callback.call).to eq 'the report test worked'
    end

    it 'runs the monthly unique auths report job' do
      job = JobRunner::Runner.configurations.find { |c| c.name == 'Unique montly auths report' }
      expect(job).to be_instance_of(JobRunner::JobConfiguration)
      expect(job.interval).to eq 24 * 60 * 60

      service = instance_double(Reports::UniqueMonthlyAuthsReport)
      expect(Reports::UniqueMonthlyAuthsReport).to receive(:new).and_return(service)
      expect(service).to receive(:call).and_return('the report test worked')

      expect(job.callback.call).to eq 'the report test worked'
    end

    it 'runs the yearly unique auths report job' do
      job = JobRunner::Runner.configurations.find { |c| c.name == 'Unique yearly auths report' }
      expect(job).to be_instance_of(JobRunner::JobConfiguration)
      expect(job.interval).to eq 24 * 60 * 60

      service = instance_double(Reports::UniqueYearlyAuthsReport)
      expect(Reports::UniqueYearlyAuthsReport).to receive(:new).and_return(service)
      expect(service).to receive(:call).and_return('the report test worked')

      expect(job.callback.call).to eq 'the report test worked'
    end

    it 'runs the agency user counts report job' do
      job = JobRunner::Runner.configurations.find { |c| c.name == 'Agency user counts report' }
      expect(job).to be_instance_of(JobRunner::JobConfiguration)
      expect(job.interval).to eq 24 * 60 * 60

      service = instance_double(Reports::AgencyUserCountsReport)
      expect(Reports::AgencyUserCountsReport).to receive(:new).and_return(service)
      expect(service).to receive(:call).and_return('the report test worked')

      expect(job.callback.call).to eq 'the report test worked'
    end

    it 'runs the total monthly auths report job' do
      job = JobRunner::Runner.configurations.find { |c| c.name == 'Total montly auths report' }
      expect(job).to be_instance_of(JobRunner::JobConfiguration)
      expect(job.interval).to eq 24 * 60 * 60

      service = instance_double(Reports::TotalMonthlyAuthsReport)
      expect(Reports::TotalMonthlyAuthsReport).to receive(:new).and_return(service)
      expect(service).to receive(:call).and_return('the report test worked')

      expect(job.callback.call).to eq 'the report test worked'
    end

    it 'runs the sp user counts report job' do
      job = JobRunner::Runner.configurations.find { |c| c.name == 'SP user counts report' }
      expect(job).to be_instance_of(JobRunner::JobConfiguration)
      expect(job.interval).to eq 24 * 60 * 60

      service = instance_double(Reports::SpUserCountsReport)
      expect(Reports::SpUserCountsReport).to receive(:new).and_return(service)
      expect(service).to receive(:call).and_return('the report test worked')

      expect(job.callback.call).to eq 'the report test worked'
    end

    it 'runs the sp user quotas report job' do
      job = JobRunner::Runner.configurations.find { |c| c.name == 'SP user quotas report' }
      expect(job).to be_instance_of(JobRunner::JobConfiguration)
      expect(job.interval).to eq 24 * 60 * 60

      service = instance_double(Reports::SpUserQuotasReport)
      expect(Reports::SpUserQuotasReport).to receive(:new).and_return(service)
      expect(service).to receive(:call).and_return('the report test worked')

      expect(job.callback.call).to eq 'the report test worked'
    end

    it 'runs the sp success rate report job' do
      job = JobRunner::Runner.configurations.find { |c| c.name == 'SP success rate report' }
      expect(job).to be_instance_of(JobRunner::JobConfiguration)
      expect(job.interval).to eq 24 * 60 * 60

      service = instance_double(Reports::SpSuccessRateReport)
      expect(Reports::SpSuccessRateReport).to receive(:new).and_return(service)
      expect(service).to receive(:call).and_return('the report test worked')

      expect(job.callback.call).to eq 'the report test worked'
    end

    it 'runs the proofing costs report job' do
      job = JobRunner::Runner.configurations.find { |c| c.name == 'Proofing costs report' }
      expect(job).to be_instance_of(JobRunner::JobConfiguration)
      expect(job.interval).to eq 24 * 60 * 60

      service = instance_double(Reports::ProofingCostsReport)
      expect(Reports::ProofingCostsReport).to receive(:new).and_return(service)
      expect(service).to receive(:call).and_return('the report test worked')

      expect(job.callback.call).to eq 'the report test worked'
    end

    it 'runs the doc auth drop offs per sprint report job' do
      job = JobRunner::Runner.configurations.find do |c|
        c.name == 'Doc auth drop off rates per sprint report'
      end
      expect(job).to be_instance_of(JobRunner::JobConfiguration)
      expect(job.interval).to eq 24 * 60 * 60

      service = instance_double(Reports::DocAuthDropOffRatesPerSprintReport)
      expect(Reports::DocAuthDropOffRatesPerSprintReport).to receive(:new).and_return(service)
      expect(service).to receive(:call).and_return('the report test worked')

      expect(job.callback.call).to eq 'the report test worked'
    end

    it 'runs the SP cost report job' do
      job = JobRunner::Runner.configurations.find do |c|
        c.name == 'SP cost report'
      end
      expect(job).to be_instance_of(JobRunner::JobConfiguration)
      expect(job.interval).to eq 24 * 60 * 60

      service = instance_double(Reports::SpCostReport)
      expect(Reports::SpCostReport).to receive(:new).and_return(service)
      expect(service).to receive(:call).and_return('the report test worked')

      expect(job.callback.call).to eq 'the report test worked'
    end

    it 'runs the total SP cost report job' do
      job = JobRunner::Runner.configurations.find do |c|
        c.name == 'Total SP cost report'
      end
      expect(job).to be_instance_of(JobRunner::JobConfiguration)
      expect(job.interval).to eq 24 * 60 * 60

      service = instance_double(Reports::TotalSpCostReport)
      expect(Reports::TotalSpCostReport).to receive(:new).and_return(service)
      expect(service).to receive(:call).and_return('the report test worked')

      expect(job.callback.call).to eq 'the report test worked'
    end

    it 'runs the SP active users report job' do
      job = JobRunner::Runner.configurations.find do |c|
        c.name == 'SP active users report'
      end
      expect(job).to be_instance_of(JobRunner::JobConfiguration)
      expect(job.interval).to eq 24 * 60 * 60

      service = instance_double(Reports::SpActiveUsersReport)
      expect(Reports::SpActiveUsersReport).to receive(:new).and_return(service)
      expect(service).to receive(:call).and_return('the report test worked')

      expect(job.callback.call).to eq 'the report test worked'
    end

    it 'runs the SP active users over period of performance report job' do
      job = JobRunner::Runner.configurations.find do |c|
        c.name == 'SP active users over period of performance report'
      end
      expect(job).to be_instance_of(JobRunner::JobConfiguration)
      expect(job.interval).to eq 24 * 60 * 60

      service = instance_double(Reports::SpActiveUsersOverPeriodOfPerformanceReport)
      expect(Reports::SpActiveUsersOverPeriodOfPerformanceReport).to receive(:new).
        and_return(service)
      expect(service).to receive(:call).and_return('the report test worked')

      expect(job.callback.call).to eq 'the report test worked'
    end

    it 'runs the doc auth drop offs report job' do
      job = JobRunner::Runner.configurations.find do |c|
        c.name == 'Doc auth drop off rates report'
      end
      expect(job).to be_instance_of(JobRunner::JobConfiguration)
      expect(job.interval).to eq 24 * 60 * 60

      service = instance_double(Reports::DocAuthDropOffRatesReport)
      expect(Reports::DocAuthDropOffRatesReport).to receive(:new).and_return(service)
      expect(service).to receive(:call).and_return('the report test worked')

      expect(job.callback.call).to eq 'the report test worked'
    end

    it 'runs the iaa billing report job' do
      job = JobRunner::Runner.configurations.find { |c| c.name == 'IAA Billing report' }
      expect(job).to be_instance_of(JobRunner::JobConfiguration)
      expect(job.interval).to eq 24 * 60 * 60

      service = instance_double(Reports::IaaBillingReport)
      expect(Reports::IaaBillingReport).to receive(:new).and_return(service)
      expect(service).to receive(:call).and_return('the report test worked')

      expect(job.callback.call).to eq 'the report test worked'
    end

    it 'emails the deleted UUIDs report' do
      job = JobRunner::Runner.configurations.find { |c| c.name == 'Deleted UUIDs report' }
      expect(job).to be_instance_of(JobRunner::JobConfiguration)
      expect(job.interval).to eq 24 * 60 * 60

      service = instance_double(Reports::DeletedUserAccountsReport)
      expect(Reports::DeletedUserAccountsReport).to receive(:new).and_return(service)
      expect(service).to receive(:call).and_return('the report test worked')

      expect(job.callback.call).to eq 'the report test worked'
    end
  end
end
