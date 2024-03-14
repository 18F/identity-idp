require 'rails_helper'
require 'reporting/fraud_metrics_lg99_report'

RSpec.describe Reporting::FraudMetricsLg99Report do
  let(:time_range) { Date.new(2022, 1, 1).all_month }
  let(:expected_lg99_metrics_table) do
    [
      ['Metric', 'Total'],
      ['Unique users seeing LG-99', '5'],
    ]
  end

  subject(:report) { Reporting::FraudMetricsLg99Report.new(time_range:) }

  before do
    cloudwatch_client = double(
      'Reporting::CloudwatchClient',
      fetch: [
        { 'user_id' => 'user1', 'name' => 'IdV: Verify please call visited' },
        { 'user_id' => 'user1', 'name' => 'IdV: Verify please call visited' },
        { 'user_id' => 'user1', 'name' => 'IdV: Verify setup errors visited' },

        { 'user_id' => 'user2', 'name' => 'IdV: Verify setup errors visited' },

        { 'user_id' => 'user3', 'name' => 'IdV: Verify please call visited' },
        { 'user_id' => 'user3', 'name' => 'IdV: Verify setup errors visited' },

        { 'user_id' => 'user4', 'name' => 'IdV: Verify please call visited' },
        { 'user_id' => 'user4', 'name' => 'IdV: Verify setup errors visited' },

        { 'user_id' => 'user5', 'name' => 'IdV: Verify please call visited' },
        { 'user_id' => 'user5', 'name' => 'IdV: Verify setup errors visited' },
      ],
    )

    allow(report).to receive(:cloudwatch_client).and_return(cloudwatch_client)
  end

  describe '#lg99_metrics_table' do
    it 'renders a lg99 metrics table' do
      aggregate_failures do
        report.lg99_metrics_table.zip(expected_lg99_metrics_table).each do |actual, expected|
          expect(actual).to eq(expected)
        end
      end
    end
  end

  describe '#as_emailable_reports' do
    let(:expected_report) do
      Reporting::EmailableReport.new(
        title: 'LG-99 Metrics',
        filename: 'lg99_metrics',
        table: expected_lg99_metrics_table,
      )
    end
    it 'return expected table for email' do
      expect(report.as_emailable_reports).to eq expected_report
    end
  end

  describe '#to_csv' do
    it 'renders a csv report' do
      aggregate_failures do
        report.lg99_metrics_table.zip(expected_lg99_metrics_table).each do |actual, expected|
          expect(actual).to eq(expected)
        end
      end
    end
  end

  describe '#cloudwatch_client' do
    let(:opts) { {} }
    let(:subject) { described_class.new(time_range:, **opts) }
    let(:default_args) do
      {
        num_threads: 5,
        ensure_complete_logs: true,
        slice_interval: 3.hours,
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
