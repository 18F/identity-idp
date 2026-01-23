# spec/lib/reporting/sp_verification_report_spec.rb
require 'rails_helper'
require 'reporting/irs_verification_report'

RSpec.describe Reporting::IrsVerificationReport do
  let(:issuers) { ['issuer1', 'issuer2'] }
  let(:agency_abbreviation) { 'Test_Partner' }

  # previous week range helper (Sunday...Saturday)
  let(:time_range) do
    last_sunday   = Time.zone.now.to_date.beginning_of_week(:sunday) - 7.days
    last_saturday = last_sunday + 6.days
    last_sunday..last_saturday
  end

  subject(:report) do
    described_class.new(
      time_range: time_range,
      issuers: issuers,
      agency_abbreviation: agency_abbreviation,
    )
  end

  before do
    mock_results = [
      { 'name' => 'IdV: doc auth welcome submitted', 'properties.user_id' => 'user1' },
      { 'name' => 'IdV: doc auth welcome submitted', 'properties.user_id' => 'user2' },
      { 'name' => 'IdV: doc auth welcome submitted', 'properties.user_id' => 'user1' },
    ]

    allow_any_instance_of(Reporting::CloudwatchClient)
      .to receive(:fetch)
      .and_return(mock_results)
  end

  describe '#overview_table' do
    it 'includes timeframe, generated date, and issuers' do
      freeze_time do
        expected_generated_date = Time.zone.today.to_s

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
    it 'computes counts and rates from the metric methods' do
      # Stub the metric calls to avoid real CloudWatch and ensure deterministic math
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
    it 'returns three CSV strings (definitions, overview, funnel)' do
      csvs = report.to_csvs

      expect(csvs).to be_an(Array)
      expect(csvs.size).to eq(3)

      # Definitions CSV
      expect(csvs.first).to include('Metric,Definition')

      # Overview CSV
      expect(csvs[1]).to include('Report Timeframe')
      expect(csvs[1]).to include('Report Generated')
      expect(csvs[1]).to include('Issuer')

      # Funnel CSV
      expect(csvs.last).to include('Metric,Count,Rate')
    end
  end
end
