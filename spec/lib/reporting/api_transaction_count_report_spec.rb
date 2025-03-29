# require 'rails_helper'
# require 'reporting/api_transaction_count_report'

# RSpec.describe Reporting::APITransactionCountReport do
#   let(:time_range) { Date.new(2025, 1, 1).all_day }

#   subject(:report) { described_class.new(time_range:) }

#   before do
#     # Stub the missing configuration
#     allow(IdentityConfig.store).to receive(:api_transaction_count_report_configs).and_return(
#       { some_key: 'some_value' }.to_json,
#     )

#     # Stub CloudWatch logs
#     stub_cloudwatch_logs(
#       [
#         {
#           'uuid' => 'user1',
#           'id' => '1',
#           'timestamp' => '2025-01-01T00:00:00Z',
#           'sp' => 'example_sp',
#           'dol_state' => 'state1',
#           'overall_process_success' => '1',
#           'document_check_vendor' => 'vendor1',
#           'resolution_vendor_name' => 'vendor2',
#           'state_id_vendor_name' => 'vendor3',
#           'tmx_review_status' => 'pass',
#         },
#         {
#           'uuid' => 'user2',
#           'id' => '2',
#           'timestamp' => '2025-01-01T01:00:00Z',
#           'sp' => 'example_sp',
#           'dol_state' => 'state2',
#           'overall_process_success' => '0',
#           'document_check_vendor' => 'vendor1',
#           'resolution_vendor_name' => 'vendor2',
#           'state_id_vendor_name' => 'vendor3',
#           'tmx_review_status' => 'fail',
#         },
#       ],
#     )
#   end

#   describe '#as_tables' do
#     it 'generates the tabular data for all queries' do
#       tables = report.as_tables

#       expect(tables).to be_an(Array)
#       expect(tables.size).to eq(5) # One table per query
#       expect(tables.first).to include(['Singular Vendor']) # First table title
#     end
#   end
# end

require 'rails_helper'
require 'reporting/mfa_report'

RSpec.describe Reporting::MfaReport do
  # Define a sample issuer and time range for the report
  let(:issuer) { 'my:example:issuer' }
  let(:time_range) { Date.new(2022, 1, 1).all_day }

  # Initialize the report with the issuer and time range
  subject(:report) { Reporting::MfaReport.new(issuers: [issuer], time_range:) }

  # Stub CloudWatch logs to simulate data returned by the CloudWatch client
  before do
    stub_cloudwatch_logs(
      [
        {
          'personal_key_total' => '2',
          'sms_total' => '5',
          'totp_total' => '4',
          'webauthn_platform_total' => '3',
          'webauthn_total' => '3',
          'backup_code_total' => '1',
          'voice_total' => '4',
          'piv_cac_total' => '3',
        },
        {
          'personal_key_total' => '1',
          'sms_total' => '4',
          'totp_total' => '3',
          'webauthn_platform_total' => '2',
          'webauthn_total' => '2',
          'backup_code_total' => '0',
          'voice_total' => '3',
          'piv_cac_total' => '2',
        },
      ],
    )
  end

  # Test the `#as_tables` method
  describe '#as_tables' do
    it 'generates the tabular csv data' do
      # Verify that the generated tables match the expected structure
      expect(report.as_tables).to eq expected_tables
    end
  end

  # Test the `#as_emailable_reports` method
  describe '#as_emailable_reports' do
    it 'adds a "first row" hash with a title for tables_report mailer' do
      # Generate the email-friendly reports
      reports = report.as_emailable_reports

      # Verify that each report includes a title
      aggregate_failures do
        reports.each do |report|
          expect(report.title).to be_present
        end
      end
    end
  end

  # Test the `#to_csvs` method
  describe '#to_csvs' do
    it 'generates a csv' do
      # Generate CSV strings for the report
      csv_string_list = report.to_csvs

      # Verify the number of CSVs generated
      expect(csv_string_list.count).to be 2

      # Parse the CSV strings into arrays
      csvs = csv_string_list.map { |csv| CSV.parse(csv) }

      # Verify that the parsed CSVs match the expected tables
      aggregate_failures do
        csvs.map(&:to_a).zip(expected_tables(strings: true)).each do |actual, expected|
          expect(actual).to eq(expected)
        end
      end
    end
  end

  # Test the `#cloudwatch_client` method
  describe '#cloudwatch_client' do
    let(:opts) { {} }
    let(:subject) { described_class.new(issuers: [issuer], time_range:, **opts) }

    # Default arguments for the CloudWatch client
    let(:default_args) do
      {
        num_threads: 10,
        ensure_complete_logs: false,
        slice_interval: 1.day,
        progress: false,
        logger: nil,
      }
    end

    # Test the default behavior of the CloudWatch client
    describe 'when all args are default' do
      it 'creates a client with the default options' do
        # Verify that the CloudWatch client is initialized with default arguments
        expect(Reporting::CloudwatchClient).to receive(:new).with(default_args)

        subject.cloudwatch_client
      end
    end

    # Test the behavior when verbose logging is enabled
    describe 'when verbose is passed in' do
      let(:opts) { { verbose: true } }
      let(:logger) { double Logger }

      before do
        # Expect a logger to be created for verbose mode
        expect(Logger).to receive(:new).with(STDERR).and_return logger
        default_args[:logger] = logger
      end

      it 'creates a client with the expected logger' do
        # Verify that the CloudWatch client is initialized with the logger
        expect(Reporting::CloudwatchClient).to receive(:new).with(default_args)

        subject.cloudwatch_client
      end
    end

    # Test the behavior when progress is enabled
    describe 'when progress is passed in as true' do
      let(:opts) { { progress: true } }
      before { default_args[:progress] = true }

      it 'creates a client with progress as true' do
        # Verify that the CloudWatch client is initialized with progress enabled
        expect(Reporting::CloudwatchClient).to receive(:new).with(default_args)

        subject.cloudwatch_client
      end
    end

    # Test the behavior when a custom thread count is specified
    describe 'when threads is passed in' do
      let(:opts) { { threads: 17 } }
      before { default_args[:num_threads] = 17 }

      it 'creates a client with the expected thread count' do
        # Verify that the CloudWatch client is initialized with the custom thread count
        expect(Reporting::CloudwatchClient).to receive(:new).with(default_args)

        subject.cloudwatch_client
      end
    end

    # Test the behavior when a custom slice interval is specified
    describe 'when slice is passed in' do
      let(:opts) { { slice: 2.weeks } }
      before { default_args[:slice_interval] = 2.weeks }

      it 'creates a client with expected time slice' do
        # Verify that the CloudWatch client is initialized with the custom slice interval
        expect(Reporting::CloudwatchClient).to receive(:new).with(default_args)

        subject.cloudwatch_client
      end
    end
  end

  # Helper method to define the expected tables for the report
  def expected_tables(strings: false)
    [
      [
        ['Report Timeframe', "#{time_range.begin} to #{time_range.end}"],
        ['Report Generated', Date.today.to_s], # rubocop:disable Rails/Date
        ['Issuer', issuer],
      ],
      [
        ['Multi Factor Authentication (MFA) method', 'Number of successful sign-ins'],
        ['SMS', string_or_num(strings, 9)],
        ['Voice', string_or_num(strings, 7)],
        ['Security key', string_or_num(strings, 5)],
        ['Face or touch unlock', string_or_num(strings, 5)],
        ['PIV/CAC', string_or_num(strings, 5)],
        ['Authentication app', string_or_num(strings, 7)],
        ['Backup codes', string_or_num(strings, 1)],
        ['Personal key', string_or_num(strings, 3)],
        ['Total number of phishing resistant methods', string_or_num(strings, 15)],
      ],
    ]
  end

  # Helper method to convert values to strings or numbers based on the `strings` flag
  def string_or_num(strings, value)
    strings ? value.to_s : value
  end
end
