require 'rails_helper'

RSpec.describe Reports::IrsWeeklySummaryReport do
  subject(:report) { Reports::IrsWeeklySummaryReport.new }
  let(:report_name) {'irs-weekly-summary-report'}
  let(:email) { 'foo@bar.com' }

  before do
    create_list(:user, 10)
  end

  describe '#perform' do
    it 'sends out a report to the email listed with system demand' do
      
      allow(IdentityConfig.store).to receive(:system_demand_report_configs).and_return(
        { 'email' => email },
      )
      allow(ReportMailer).to receive(:system_demand_report).and_call_original
  
      report = "Data Requested,Total Count\nSystem Demand,10\n"
      expect(ReportMailer).to receive(:system_demand_report).with(
        email: email, data: report, name: report_name
      )

      subject.perform(Time.now)
    end

    it 'uploads a file to S3 based on the report date' do
      csv_data = CSV.parse(subject.perform(Time.now), headers: true)
      expect(csv_data[0]['Total Count']).to eq('10') 

    end
  end
end