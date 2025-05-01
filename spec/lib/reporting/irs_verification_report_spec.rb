require 'rails_helper'
require 'reporting/irs_verification_report'

RSpec.describe Reporting::IrsVerificationReport do
  let(:time_range) do
    Time.zone.today.beginning_of_week(:sunday) - 7.days..
      Time.zone.today.end_of_week(:saturday) - 7.days
  end
  let(:issuers) { ['issuer1', 'issuer2'] }
  let(:mock_results) { [{ 'name' => 'IdV: doc auth welcome visited', 'user_id' => 'user1' }] }

  subject(:report) { described_class.new(time_range: time_range, issuers: issuers) }

  before do
    allow_any_instance_of(Reporting::CloudwatchClient).to receive(:fetch).and_return(mock_results)
  end

  describe '#overview_table' do
    it 'generates the overview table with the correct data' do
      table = report.overview_table

      expect(table).to include(
        ['Report Timeframe', "#{time_range.begin.to_date} to #{time_range.end.to_date}"],
        ['Report Generated', Time.zone.today.to_s],
        ['Issuer', issuers.join(', ')],
      )
    end
  end

  describe '#funnel_table' do
    it 'generates the funnel table with the correct metrics' do
      allow(report).to receive(:verification_demand_results).and_return(100)
      allow(report).to receive(:document_authentication_success_results).and_return(80)
      allow(report).to receive(:information_validation_success_results).and_return(70)
      allow(report).to receive(:phone_verification_success_results).and_return(60)
      allow(report).to receive(:total_verified_results).and_return(50)

      table = report.funnel_table

      expect(table).to include(
        ['Metric', 'Count', 'Rate'],
        ['Verfication Demand', 100, 100.0],
        ['Document Authentication Success', 80, 80.0],
        ['Information Verification Success', 70, 70.0],
        ['Phone Verification Success', 60, 60.0],
        ['Total Verified Success', 50, 50.0],
        ['Verification Fallouts', 50, 50.0],
      )
    end
  end

  describe '#to_csvs' do
    it 'generates CSVs for the reports' do
      csvs = report.to_csvs

      expect(csvs).to be_an(Array)
      expect(csvs.size).to eq(2) # One for each table
      expect(csvs.first).to include('Report Timeframe')
      expect(csvs.last).to include('Metric,Count,Rate')
    end
  end
end