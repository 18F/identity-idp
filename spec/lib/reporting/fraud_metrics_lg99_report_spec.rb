require 'rails_helper'
require 'reporting/fraud_metrics_lg99_report'

RSpec.describe Reporting::FraudMetricsLg99Report do
  let(:time_range) { Date.new(2022, 1, 1).in_time_zone('UTC').all_month }
  let(:expected_lg99_metrics_table) do
    [
      ['Metric', 'Total'],
      ['Unique users seeing LG-99', '5'],
      ['Unique users suspended', '2'],
      ['Average Days Creation to Suspension', '1.5'],
      ['Average Days Proofed to Suspension', '2.0'],
      ['Unique users reinstated', '1'],
      ['Average Days to Reinstatement', '3.0'],
    ]
  end
  let!(:user6) do
    create(
      :user,
      :proofed,
      :reinstated,
      uuid: 'user6',
      suspended_at: 3.days.from_now,
      reinstated_at: 6.days.from_now,
    )
  end
  let!(:user7) { create(:user, :proofed, :suspended, uuid: 'user7') }

  subject(:report) { Reporting::FraudMetricsLg99Report.new(time_range:) }

  before do
    stub_cloudwatch_logs(
      [
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

        { 'user_id' => 'user6', 'name' => 'User Suspension: Suspended' },
        { 'user_id' => 'user6', 'name' => 'User Suspension: Reinstated' },

        { 'user_id' => 'user7', 'name' => 'User Suspension: Suspended' },
      ],
    )
    user7.profiles.verified.last.update(created_at: 1.day.ago, activated_at: 1.day.ago) if user7
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

  describe '#user_days_to_suspension_avg' do
    context 'when there are suspended users' do
      it 'returns average time to suspension' do
        expect(report.user_days_to_suspension_avg).to eq(1.5)
      end
    end

    context 'when there are no users' do
      let(:user6) { nil }
      let(:user7) { nil }

      it 'returns n/a' do
        expect(report.user_days_to_suspension_avg).to eq('n/a')
      end
    end
  end

  describe '#user_days_to_reinstatement_avg' do
    context 'where there are reinstated users' do
      it 'returns average time to reinstatement' do
        expect(report.user_days_to_reinstatement_avg).to eq(3.0)
      end
    end

    context 'when there are no users' do
      let(:user6) { nil }
      let(:user7) { nil }

      it 'returns n/a' do
        expect(report.user_days_to_reinstatement_avg).to eq('n/a')
      end
    end
  end

  describe '#user_days_proofed_to_suspended_avg' do
    context 'when there are suspended users' do
      it 'returns average time proofed to suspension' do
        expect(report.user_days_proofed_to_suspension_avg).to eq(2.0)
      end
    end

    context 'when there are no users' do
      let(:user6) { nil }
      let(:user7) { nil }

      it 'returns n/a' do
        expect(report.user_days_proofed_to_suspension_avg).to eq('n/a')
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
