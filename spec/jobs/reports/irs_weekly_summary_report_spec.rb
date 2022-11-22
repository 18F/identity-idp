require 'rails_helper'

RSpec.describe Reports::IrsWeeklySummaryReport do
  subject(:report) { Reports::IrsWeeklySummaryReport.new }

  let(:report_date) { Date.new(2021, 3, 7) } 
  #let(:s3_public_reports_enabled) { true }

  before do
    create_list(:user, 10)
  end

  describe '#perform' do
    it 'uploads a file to S3 based on the report date' do
      csv_data = CSV.parse(Reports::IrsWeeklySummaryReport.new.perform(Time.now + 3.months), headers: true)
      expect(csv_data[0]['total login.gov']).to eq('10') # for row 1, system demand 
      expect(csv_data[1]['total login.gov']).to eq('3') # for row 2, credential tenure

    end
  end
end