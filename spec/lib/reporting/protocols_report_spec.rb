require 'rails_helper'
require 'reporting/protocols_report'

RSpec.describe Reporting::ProtocolsReport do
  let(:time_range) { Date.new(2022, 1, 1).all_day }

  subject(:report) { Reporting::ProtocolsReport.new(issuers: nil, time_range:) }

  before do
    protocol_query_response = [
      {
        'protocol' => 'SAML Auth',
        'request_count' => '8',
      },
      {
        'protocol' => 'SAML Auth',
        'request_count' => '2',
      },
      {
        'protocol' => 'SAML Auth',
        'request_count' => '10',
      },
      {
        'protocol' => 'OpenID Connect: authorization request',
        'request_count' => '80',
      },
    ]
    saml_signature_query_response = [
      {
        'issuer' => 'Issuer1',
        'unsigned_count' => '2',
        'invalid_signature_count' => '0',
      },
      {
        'issuer' => 'Issuer1',
        'unsigned_count' => '5',
        'invalid_signature_count' => '0',
      },
      {
        'issuer' => 'Issuer3',
        'unsigned_count' => '3',
        'invalid_signature_count' => '0',
      },
      {
        'issuer' => 'Issuer2',
        'unsigned_count' => '0',
        'invalid_signature_count' => '0',
      },
      {
        'issuer' => 'Issuer1',
        'unsigned_count' => '8',
        'invalid_signature_count' => '2',
      },
    ]
    cloudwatch_client = instance_double('Reporting::CloudwatchClient')
    allow(cloudwatch_client).to receive(:fetch).and_return(
      protocol_query_response,
      saml_signature_query_response,
    )

    allow(report).to receive(:cloudwatch_client).and_return(cloudwatch_client)
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
      expect(csv_string_list.count).to be 3

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
    let(:subject) { described_class.new(issuers: nil, time_range:, **opts) }
    let(:default_args) do
      {
        num_threads: 10,
        ensure_complete_logs: true,
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
      ],
      [
        ['Authentication Protocol', '% of attempts', 'Total number'],
        ['SAML', string_or_num(strings, 20.0), string_or_num(strings, 20)],
        ['OIDC', string_or_num(strings, 80.0), string_or_num(strings, 80)],
      ],
      [
        ['Issue', 'Count of integrations with the issue', 'List of issuers with the issue'],
        ['Not signing SAML authentication requests', string_or_num(strings, 2), 'Issuer1, Issuer3'],
        ['Incorrectly signing SAML authentication requests', string_or_num(strings, 1), 'Issuer1'],
      ],
    ]
  end

  def string_or_num(strings, value)
    strings ? value.to_s : value
  end
end
