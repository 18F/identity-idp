require 'rails_helper'
require 'reporting/api_transaction_count_report'

RSpec.describe Reporting::ApiTransactionCountReport do
  let(:time_range) do
    Time.zone.today.beginning_of_week(:sunday)..Time.zone.today.end_of_week(:saturday)
  end
  subject(:report) { described_class.new(time_range: time_range) }

  describe '#api_transaction_count' do
    it 'returns the expected table structure' do
      allow(report).to receive(:true_id_table).and_return([10, []])
      allow(report).to receive(:singular_vendor_table).and_return([15, []])
      allow(report).to receive(:phone_finder_table).and_return([20, []])
      allow(report).to receive(:acuant_table).and_return([25, []])
      allow(report).to receive(:socure_table).and_return([30, []])
      allow(report).to receive(:fraud_score_and_attribute_table).and_return([35, []])
      allow(report).to receive(:instant_verify_table).and_return([40, []])
      allow(report).to receive(:threat_metrix_table).and_return([45, []])

      result = report.api_transaction_count

      expect(result).to eq(
        [
          [
            'Week',
            'True ID',
            'Instant verify',
            'Phone Finder',
            'Acuant',
            'Socure',
            'Fraud Score and Attribute',
            'Instant Verify',
            'Threat Metrix',
          ],
          [
            "#{time_range.begin.to_date} - #{time_range.end.to_date}",
            10,
            15,
            20,
            25,
            30,
            35,
            40,
            45,
          ],
        ],
      )
    end
  end

  describe '#as_emailable_reports' do
    it 'returns an array of EmailableReport objects' do
      allow(report).to receive(:api_transaction_count).and_return(
        [
          ['Week', 'True ID',
           'Instant verify'],
          [
            '2023-04-14 - 2023-04-20', 10, 20
          ],
        ],
      )

      result = report.as_emailable_reports

      expect(result).to be_an(Array)
      expect(result.first).to be_a(Reporting::EmailableReport)
      expect(result.first.title).to eq('API Transaction Count Report')
      expect(result.first.filename).to eq('api_transaction_count_report')
      expect(result.first.table).to eq(
        [
          ['Week', 'True ID', 'Instant verify'],
          ['2023-04-14 - 2023-04-20', 10, 20],
        ],
      )
    end
  end

  describe '#to_csvs' do
    it 'generates CSVs for each emailable report' do
      allow(report).to receive(:api_transaction_count).and_return(
        [
          ['Week', 'True ID',
           'Instant verify'],
          [
            '2023-04-14 - 2023-04-20', 10, 20
          ],
        ],
      )

      csvs = report.to_csvs

      expect(csvs).to be_an(Array)
      expect(csvs.first).to include('Week,True ID,Instant verify')
      expect(csvs.first).to include('2023-04-14 - 2023-04-20,10,20')
    end
  end

  describe '#fetch_results' do
    it 'logs and returns results from the cloudwatch client' do
      mock_results = [{ 'uuid' => '123', 'id' => '1' }]
      mock_client = instance_double(Reporting::CloudwatchClient, fetch: mock_results)

      allow(report).to receive(:cloudwatch_client).and_return(mock_client)

      results = report.send(:fetch_results, query: 'mock_query')

      expect(results).to eq(mock_results)
    end

    it 'returns an empty array if an error occurs' do
      allow(report).to receive(:cloudwatch_client).and_raise(StandardError, 'mock error')

      results = report.send(:fetch_results, query: 'mock_query')

      expect(results).to eq([])
    end
  end
end
