require 'rails_helper'
require 'reporting/irs_verification_report'

RSpec.describe Reporting::IrsVerificationReport do
  let(:time_range) { previous_week_range }
  let(:issuers) { ['issuer1', 'issuer2'] }
  let(:mock_results) { [{ 'name' => 'IdV: doc auth welcome visited', 'user_id' => 'user1' }] }

  subject(:report) { described_class.new(time_range: time_range, issuers: issuers) }

  before do
    allow_any_instance_of(Reporting::CloudwatchClient).to receive(:fetch).and_return(mock_results)
  end

  def previous_week_range
    one_week = 7.days
    last_sunday = Time.current.utc.to_date.beginning_of_week(:sunday) - one_week
    last_saturday = last_sunday + 6.days
    last_sunday..last_saturday
  end

  describe '#overview_table' do
    it 'generates the overview table with the correct data' do
      freeze_time do
        expected_generated_date = Time.current.utc.to_date.to_s

        table = report.overview_table

        expect(table).to include(
          ['Report Timeframe', "#{time_range.begin.to_date} to #{time_range.end.to_date}"],
          ['Report Generated', expected_generated_date],
          ['Issuer', issuers.join(', ')],
        )
      end
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
        ['Verification Demand', 100, 1.0],
        ['Document Authentication Success', 80, 0.8],
        ['Information Verification Success', 70, 0.7],
        ['Phone Verification Success', 60, 0.6],
        ['Verification Successes', 50, 0.5],
        ['Verification Failures', 50, 0.5],
      )
    end
  end

  describe '#to_csvs' do
    it 'generates CSVs for the reports' do
      csvs = report.to_csvs

      expect(csvs).to be_an(Array)
      expect(csvs.size).to eq(3) # One for each table

      # First CSV: Definitions
      expect(csvs.first).to include('Metric,Definition')

      # Second CSV: Overview table
      expect(csvs[1]).to include('Report Timeframe')
      expect(csvs[1]).to include('Report Generated')
      expect(csvs[1]).to include('Issuer')

      # Third CSV: Funnel table
      expect(csvs.last).to include('Metric,Count,Rate')
    end
  end
end
