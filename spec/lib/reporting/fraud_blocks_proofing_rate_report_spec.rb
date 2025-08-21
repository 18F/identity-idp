require 'rails_helper'
require 'reporting/fraud_blocks_proofing_rate_report'

RSpec.describe Reporting::FraudBlocksProofingRateReport do
  let(:issuer) { 'my:example:issuer' }
  let(:time_range) { Date.new(2022, 1, 1).in_time_zone('UTC').all_month }
  let(:suspected_fraud_blocks_metrics_table) do
    [
      ['Metric', 'Total', 'Range Start', 'Range End'],
      ['Authentic Drivers License', '10', time_range.begin.to_s, time_range.end.to_s],
      ['Valid Drivers License #', '4', time_range.begin.to_s, time_range.end.to_s],
      ['Facial Matching Check', '4', time_range.begin.to_s, time_range.end.to_s],
      ['Identity Not Found', '10', time_range.begin.to_s, time_range.end.to_s],
      ['Address / Occupancy Match', '4', time_range.begin.to_s, time_range.end.to_s],
      ['Social Security Number Match', '4', time_range.begin.to_s, time_range.end.to_s],
      ['Date of Birth Match', '10', time_range.begin.to_s, time_range.end.to_s],
      ['Deceased Check', '4', time_range.begin.to_s, time_range.end.to_s],
      ['Phone Account Ownership', '4', time_range.begin.to_s, time_range.end.to_s],
      ['Device and Behavior Fraud Signals', '4', time_range.begin.to_s, time_range.end.to_s],
    ]
  end

  let(:key_points_user_friction_metrics_table) do
    [
      ['Metric', 'Total', 'Range Start', 'Range End'],
      ['Document / selfie upload UX challenge', '30', time_range.begin.to_s, time_range.end.to_s],
      ['Verification code not received', '10', time_range.begin.to_s, time_range.end.to_s],
      ['API connection fails', '4', time_range.begin.to_s, time_range.end.to_s],
    ]
  end

  let(:successful_ipp_table) do
    [
      ['Metric', 'Total', 'Range Start', 'Range End'],
      ['Successful IPP', '12000', time_range.begin.to_s, time_range.end.to_s],
    ]
  end

  subject(:report) { Reporting::FraudBlocksProofingRateReport.new(issuers: [issuer], time_range:) }

  before do
    travel_to Time.zone.now.beginning_of_day
    stub_cloudwatch_logs(
      [{ 'document_fail_count_socure' => '5', 'facial_match_fail_count_socure' => '2' },
       { 'document_fail_count_lexis' => '5', 'facial_match_fail_count_lexis' => '2' },
       { 'aamva_failed_count' => '4' },
       { 'address_failed_count' => '4',
         'dob_failed_count' => '10',
         'death_failed_count' => '4',
         'ssn_failed_count' => '4',
         'identity_not_found_count' => '10' },
       { 'phone_finder_fail_count' => '4' },
       { 'DeviceBehavoirFraudSig' => '4' },
       { 'sum_capture_quality_fail' => '15' },
       { 'sum_any_capture' => '15' },
       { 'sum_verification_code_not_received' => '10' },
       { 'api_user_fail' => '4',
         'AAMVA_fail_count' => '1',
         'LN_timeout_fail_count' => '1',
         'state_timeout_fail_count' => '2' },
       { 'IPP_successfully_proofed_user_counts' => '12000' }],
    )
  end

  describe '#suspected_fraud_blocks_metrics_table' do
    it 'renders a suspected fraud blocks metrics table' do
      aggregate_failures do
        report.suspected_fraud_blocks_metrics_table.zip(expected_suspected_fraud_blocks_metrics_table).each do |actual, expected|
          expect(actual).to eq(expected)
        end
      end
    end
  end

  describe '#key_points_user_friction_metrics_table' do
    it 'renders a key points user friction metrics table' do
      aggregate_failures do
        report.key_points_user_friction_metrics_table.zip(expected_key_points_user_friction_metrics_table).each do |actual, expected|
          expect(actual).to eq(expected)
        end
      end
    end
  end

  describe '#successful_ipp_table' do
    it 'renders a successful ipp table' do
      aggregate_failures do
        report.successful_ipp_table.zip(expected_successful_ipp_table).each do |actual, expected|
          expect(actual).to eq(expected)
        end
      end
    end
  end

  describe '#as_emailable_reports' do
    let(:expected_reports) do
      [
        Reporting::EmailableReport.new(
          title: 'Suspected_Fraud_Blocks_Metircs',
          filename: 'suspected_fraud_blocks_metrics',
          table: expected_suspected_fraud_blocks_metrics_table,
        ),
        Reporting::EmailableReport.new(
          title: 'Key_Points_User_Friction_Metrics',
          filename: 'key_points_user_friction_metrics',
          table: expected_key_points_user_friction_metrics_table,
        ),
        Reporting::EmailableReport.new(
          title: 'Successful_IPP',
          filename: 'successful_ipp',
          table: expected_successful_ipp_table,
        ),
      ]
    end
    # TODO: END ---------------------------------------------
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
