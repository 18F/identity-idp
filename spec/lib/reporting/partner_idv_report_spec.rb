require 'rails_helper'
require 'reporting/partner_idv_report'

RSpec.describe Reporting::PartnerIdvReport do
  let(:service_provider_id) { 42 }
  let(:month_start_calendar_id) { 202401 }
  let(:cluster_id) { 'test-cluster' }
  let(:database) { 'test_db' }
  let(:db_user) { 'test_user' }

  subject(:report) do
    described_class.new(
      service_provider_id: service_provider_id,
      month_start_calendar_id: month_start_calendar_id,
      cluster_id: cluster_id,
      database: database,
      db_user: db_user,
    )
  end

  let(:mock_redshift_client) { instance_double(Aws::RedshiftDataAPIService::Client) }

  let(:column_metadata) do
    [
      double(name: 'issuer'),
      double(name: 'service_provider_name'),
      double(name: 'count_inauthentic_doc'),
    ]
  end

  let(:statement_result) do
    double(
      column_metadata: column_metadata,
      records: [
        [
          double(is_null: false, string_value: 'urn:test:issuer', long_value: nil,
                 double_value: nil, boolean_value: nil),
          double(is_null: false, string_value: 'Test SP', long_value: nil,
                 double_value: nil, boolean_value: nil),
          double(is_null: false, string_value: nil, long_value: 5,
                 double_value: nil, boolean_value: nil),
        ],
      ],
    )
  end

  let(:statement_id) { 'stmt-12345' }

  before do
    allow(report).to receive(:redshift_client).and_return(mock_redshift_client)

    allow(mock_redshift_client).to receive(:execute_statement).and_return(
      double(id: statement_id),
    )

    allow(mock_redshift_client).to receive(:describe_statement).and_return(
      double(status: 'FINISHED', error: nil),
    )

    allow(mock_redshift_client).to receive(:get_statement_result).and_return(statement_result)
  end

  describe '#fetch_results' do
    it 'returns an array of hashes with column names as keys' do
      results = report.fetch_results

      expect(results).to eq(
        [
          {
            'issuer' => 'urn:test:issuer',
            'service_provider_name' => 'Test SP',
            'count_inauthentic_doc' => 5,
          },
        ],
      )
    end

    it 'calls execute_statement with the correct parameters' do
      expect(mock_redshift_client).to receive(:execute_statement).with(
        cluster_identifier: cluster_id,
        database: database,
        db_user: db_user,
        sql: described_class::REDSHIFT_QUERY,
        parameters: [
          { name: 'service_provider_id', value: service_provider_id.to_s },
          { name: 'month_start_calendar_id', value: month_start_calendar_id.to_s },
        ],
      ).and_return(double(id: statement_id))

      report.fetch_results
    end

    it 'polls until the statement finishes' do
      call_count = 0
      allow(mock_redshift_client).to receive(:describe_statement) do
        call_count += 1
        status = call_count < 3 ? 'STARTED' : 'FINISHED'
        double(status: status, error: nil)
      end
      allow(report).to receive(:sleep)

      report.fetch_results

      expect(call_count).to eq(3)
    end

    context 'when the statement times out' do
      before do
        allow(mock_redshift_client).to receive(:describe_statement).and_return(
          double(status: 'STARTED', error: nil),
        )
        allow(report).to receive(:sleep)
        # Simulate deadline already passed on first check
        allow(Time).to receive(:now).and_return(
          Time.now,
          Time.now + described_class::MAX_POLL_SECONDS + 1,
        )
      end

      it 'raises a timeout error' do
        expect { report.fetch_results }.to raise_error(RuntimeError, /did not finish/)
      end
    end

    context 'when the statement fails' do
      before do
        allow(mock_redshift_client).to receive(:describe_statement).and_return(
          double(status: 'FAILED', error: 'syntax error'),
        )
      end

      it 'raises an error' do
        expect { report.fetch_results }.to raise_error(RuntimeError, /FAILED/)
      end
    end
  end

  describe '#results_json' do
    it 'returns a JSON string of the fetch results' do
      json = report.results_json

      expect(json).to be_a(String)
      parsed = JSON.parse(json)
      expect(parsed).to be_an(Array)
      expect(parsed.first['issuer']).to eq('urn:test:issuer')
    end
  end

  describe '#redshift_client' do
    subject(:fresh_report) do
      described_class.new(
        service_provider_id: service_provider_id,
        month_start_calendar_id: month_start_calendar_id,
      )
    end

    it 'returns an Aws::RedshiftDataAPIService::Client instance' do
      expect(fresh_report.redshift_client).to be_an(Aws::RedshiftDataAPIService::Client)
    end

    it 'memoizes the client' do
      client = fresh_report.redshift_client
      expect(fresh_report.redshift_client).to be(client)
    end
  end
end
