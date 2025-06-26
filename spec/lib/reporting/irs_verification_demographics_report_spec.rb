require 'rails_helper'
require 'reporting/irs_verification_demographics_report'

RSpec.describe Reporting::IrsVerificationDemographicsReport do
  let(:issuer) { 'my:example:issuer' }
  let(:time_range) { Date.new(2022, 1, 1).in_time_zone('UTC').all_quarter }
  let(:expected_definitions_table) do
    [
      ['Metric', 'Unit', 'Definition'],
      ['Verified users by age', 'Count',
       'The number of users grouped by age in 10 year range.'],
      ['Verified users by state', 'Count',
       'The number of users grouped by state.'],
    ]
  end
  let(:expected_overview_table) do
    [
      ['Report Timeframe', "#{time_range.begin} to #{time_range.end}"],
      ['Report Generated', Time.zone.today.to_s],
      ['Issuer', issuer],
    ]
  end
  let(:expected_age_metrics_table) do
    [
      ['Age Range', 'User Count'],
      ['10-19', '2'],
      ['20-29', '2'],
      ['30-39', '2'],
    ]
  end
  let(:expected_state_metrics_table) do
    [
      ['State', 'User Count'],
      ['DE', '2'],
      ['MD', '2'],
      ['VA', '2'],
    ]
  end

  subject(:report) do
    Reporting::IrsVerificationDemographicsReport.new(issuers: [issuer], time_range:)
  end

  before do
    travel_to Time.zone.now.beginning_of_day
    stub_cloudwatch_logs(
      [
        { 'user_id' => 'user1',
          'name' => 'IdV: doc auth verify proofing results',
          'birth_year' => '2014',
          'state' => 'MD' },
        
        { 'user_id' => 'user1',
          'name' => 'SP redirect initiated'},

        { 'user_id' => 'user2',
          'name' => 'IdV: doc auth verify proofing results',
          'birth_year' => '2014',
          'state' => 'MD' },

        { 'user_id' => 'user2',
          'name' => 'SP redirect initiated'},

        { 'user_id' => 'user3',
          'name' => 'IdV: doc auth verify proofing results',
          'birth_year' => '2005',
          'state' => 'DE' },

        { 'user_id' => 'user3',
          'name' => 'SP redirect initiated'},

        { 'user_id' => 'user4',
          'name' => 'IdV: doc auth verify proofing results',
          'birth_year' => '2005',
          'state' => 'DE' },

        { 'user_id' => 'user4',
          'name' => 'SP redirect initiated'},

        { 'user_id' => 'user5',
          'name' => 'IdV: doc auth verify proofing results',
          'birth_year' => '1995',
          'state' => 'VA' },

        { 'user_id' => 'user5',
          'name' => 'SP redirect initiated'},

        { 'user_id' => 'user6',
          'name' => 'IdV: doc auth verify proofing results',
          'birth_year' => '1995',
          'state' => 'VA' },

        { 'user_id' => 'user6',
          'name' => 'SP redirect initiated'},
          
      ],
    )
  end

  describe '#definitions_table' do
    it 'renders a definitions table' do
      aggregate_failures do
        report.definitions_table.zip(expected_definitions_table).each do |actual, expected|
          expect(actual).to eq(expected)
        end
      end
    end
  end

  describe '#overview_table' do
    it 'renders an overview table' do
      aggregate_failures do
        report.overview_table.zip(expected_overview_table).each do |actual, expected|
          expect(actual).to eq(expected)
        end
      end
    end
  end

  describe '#age_metrics_table' do
    it 'renders an age metrics table' do
      aggregate_failures do
        report.age_metrics_table.zip(expected_age_metrics_table).each do |actual, expected|
          expect(actual).to eq(expected)
        end
      end
    end
  end

  describe '#state_metrics_table' do
    it 'renders a state metrics table' do
      aggregate_failures do
        report.state_metrics_table.zip(expected_state_metrics_table)
          .each do |actual, expected|
            expect(actual).to eq(expected)
          end
      end
    end
  end

  describe '#as_emailable_reports' do
    let(:expected_reports) do
      [
        Reporting::EmailableReport.new(
          title: 'Definitions',
          filename: 'definitions',
          table: expected_definitions_table,
        ),
        Reporting::EmailableReport.new(
          title: 'Overview',
          filename: 'overview',
          table: expected_overview_table,
        ),
        Reporting::EmailableReport.new(
          title: 'IRS Age Metrics',
          filename: 'age_metrics',
          table: expected_age_metrics_table,
        ),
        Reporting::EmailableReport.new(
          title: 'IRS State Metrics',
          filename: 'state_metrics',
          table: expected_state_metrics_table,
        ),
      ]
    end
    it 'return expected table for email' do
      expect(report.as_emailable_reports).to eq expected_reports
    end
  end

  describe '#cloudwatch_client' do
    let(:opts) { {} }
    let(:subject) { described_class.new(issuers: [issuer], time_range:, **opts) }
    let(:default_args) do
      {
        num_threads: 1,
        ensure_complete_logs: true,
        slice_interval: 6.hours,
        progress: false,
        logger: nil,
      }
    end

    describe 'when all args are default' do
      it 'creates a client with the default options' do
        expect(Reporting::CloudwatchClient).to receive(:new).with(default_args)

        subject.cloudwatch_client
      end
    end

    describe 'when verbose is passed in' do
      let(:opts) { { verbose: true } }
      let(:logger) { double Logger }

      before do
        expect(Logger).to receive(:new).with(STDERR).and_return logger
        default_args[:logger] = logger
      end

      it 'creates a client with the expected logger' do
        expect(Reporting::CloudwatchClient).to receive(:new).with(default_args)

        subject.cloudwatch_client
      end
    end

    describe 'when progress is passed in as true' do
      let(:opts) { { progress: true } }
      before { default_args[:progress] = true }

      it 'creates a client with progress as true' do
        expect(Reporting::CloudwatchClient).to receive(:new).with(default_args)

        subject.cloudwatch_client
      end
    end

    describe 'when threads is passed in' do
      let(:opts) { { threads: 17 } }
      before { default_args[:num_threads] = 17 }

      it 'creates a client with the expected thread count' do
        expect(Reporting::CloudwatchClient).to receive(:new).with(default_args)

        subject.cloudwatch_client
      end
    end

    describe 'when slice is passed in' do
      let(:opts) { { slice: 2.weeks } }
      before { default_args[:slice_interval] = 2.weeks }

      it 'creates a client with expected time slice' do
        expect(Reporting::CloudwatchClient).to receive(:new).with(default_args)

        subject.cloudwatch_client
      end
    end
  end
end
