require 'rails_helper'
require 'reporting/mfa_report'

RSpec.describe Reporting::MfaReport do
  let(:issuer) { 'my:example:issuer' }
  let(:time_range) { Date.new(2022, 1, 1).all_day }

  subject(:report) { Reporting::MfaReport.new(issuers: [issuer], time_range:) }

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

  describe '#as_tables' do
    it 'generates the tabular csv data' do
      expect(report.as_tables).to eq expected_tables
    end
  end

  describe '#as_emailable_reports' do
    it 'adds a "first row" hash with a title for tables_report mailer' do
      reports = report.as_emailable_reports
      aggregate_failures do
        reports.each do |report|
          expect(report.title).to be_present
        end
      end
    end
  end

  describe '#to_csvs' do
    it 'generates a csv' do
      csv_string_list = report.to_csvs
      expect(csv_string_list.count).to be 2

      csvs = csv_string_list.map { |csv| CSV.parse(csv) }

      aggregate_failures do
        csvs.map(&:to_a).zip(expected_tables(strings: true)).each do |actual, expected|
          expect(actual).to eq(expected)
        end
      end
    end
  end

  describe '#cloudwatch_client' do
    let(:opts) { {} }
    let(:subject) { described_class.new(issuers: [issuer], time_range:, **opts) }
    let(:default_args) do
      {
        num_threads: 10,
        ensure_complete_logs: false,
        slice_interval: 1.day,
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

  def string_or_num(strings, value)
    strings ? value.to_s : value
  end
end
