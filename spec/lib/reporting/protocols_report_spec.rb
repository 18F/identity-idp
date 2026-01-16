require 'rails_helper'
require 'reporting/protocols_report'

RSpec.describe Reporting::ProtocolsReport do
  let(:time_range) { Date.new(2022, 1, 1).all_day }

  subject(:report) { Reporting::ProtocolsReport.new(issuers: nil, time_range:) }

  before do
    protocol_query_response = [
      {
        'protocol' => 'SAML Auth',
        'issuer' => 'Issuer 1',
        'request_count' => '8',
      },
      {
        'protocol' => 'SAML Auth',
        'issuer' => 'Issuer 1',
        'request_count' => '2',
      },
      {
        'protocol' => 'SAML Auth',
        'issuer' => 'Issuer 2',
        'request_count' => '10',
      },
      {
        'protocol' => 'OpenID Connect: authorization request',
        'issuer' => 'Issuer 3',
        'request_count' => '60',
      },
      {
        'protocol' => 'OpenID Connect: authorization request',
        'issuer' => 'Issuer 4',
        'request_count' => '20',
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
    loa_issuers_query_response = [
      {
        'issuer' => 'Issuer1',
      },
      {
        'issuer' => 'Issuer2',
      },
      {
        'issuer' => 'Issuer3',
      },
    ]
    aal3_issuers_query_response = [
      {
        'issuer' => 'Issuer1',
      },
      {
        'issuer' => 'Issuer3',
      },
    ]

    facial_match_issuers_query_response = [
      {
        'issuer' => 'Issuer1',
      },
      {
        'issuer' => 'Issuer8',
      },
    ]

    id_token_hint_query_response = [
      {
        'issuer' => 'Issuer3',
      },
      {
        'issuer' => 'Issuer4',
      },
    ]

    no_openid_scope_query_response = [
      {
        'issuer' => 'Issuer1',
      },
      {
        'issuer' => 'Issuer2',
      },
    ]

    stub_multiple_cloudwatch_logs(
      protocol_query_response,
      saml_signature_query_response,
      loa_issuers_query_response,
      aal3_issuers_query_response,
      id_token_hint_query_response,
      no_openid_scope_query_response,
      facial_match_issuers_query_response,
    )
  end

  describe '#as_tables' do
    it 'generates the tabular csv data' do
      expect(report.as_tables).to eq expected_tables
    end

    describe 'queries' do
      let(:client) { report.cloudwatch_client }
      let(:time_query) do
        {
          from: report.time_range.begin,
          to: report.time_range.end,
        }
      end
      before do
        allow(client).to receive(:fetch).and_call_original
      end

      it 'calls the cloudwatch client with the expected queries' do
        report.as_tables

        %i[
          aal3_issuers_query
          saml_signature_query
          facial_match_issuers_query
          id_token_hint_query
          loa_issuers_query
          protocol_query
          saml_signature_query
          no_openid_scope_query
        ].each do |query|
          expect(client).to have_received(:fetch).with(
            query: report.public_send(query),
            **time_query,
          )
        end
      end
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
      expect(csv_string_list.count).to be 5

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
      ],
      [
        ['Authentication Protocol', '% of requests', 'Total requests', 'Count of issuers'],
        ['SAML', string_or_num(strings, 20.0), string_or_num(strings, 20),
         string_or_num(strings, 2)],
        ['OIDC', string_or_num(strings, 80.0), string_or_num(strings, 80),
         string_or_num(strings, 2)],
      ],
      [
        ['Issue', 'Count of issuers', 'List of issuers'],
        ['Not signing SAML authentication requests', string_or_num(strings, 2), 'Issuer1, Issuer3'],
        ['Incorrectly signing SAML authentication requests', string_or_num(strings, 1), 'Issuer1'],
      ],
      [
        [
          'Deprecated Parameter',
          'Count of issuers',
          'List of issuers',
        ],
        [
          'LOA',
          string_or_num(strings, 3),
          'Issuer1, Issuer2, Issuer3',
        ],
        [
          'AAL3',
          string_or_num(strings, 2),
          'Issuer1, Issuer3',
        ],
        [
          'id_token_hint',
          string_or_num(strings, 2),
          'Issuer3, Issuer4',
        ],
        [
          'No openid in scope',
          string_or_num(strings, 2),
          'Issuer1, Issuer2',
        ],
      ],
      [
        [
          'Feature',
          'Count of issuers',
          'List of issuers',
        ],
        [
          'IdV with Facial Match',
          string_or_num(strings, 2),
          'Issuer1, Issuer8',
        ],
      ],
    ]
  end

  def string_or_num(strings, value)
    strings ? value.to_s : value
  end
end
