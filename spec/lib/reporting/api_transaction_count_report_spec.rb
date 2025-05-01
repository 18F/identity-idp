require 'rails_helper'
require 'reporting/api_transaction_count_report'

RSpec.describe Reporting::ApiTransactionCountReport do
  let(:time_range) { Date.new(2022, 1, 1).in_time_zone('UTC').all_month }
  let(:mock_results) do
    [
      { 'uuid' => '123', 'id' => '1', 'sp' => 'SP1' },
      { 'uuid' => '456', 'id' => '2', 'sp' => 'SP2' },
      { 'uuid' => '789', 'id' => '3', 'sp' => 'SP3' },
    ]
  end

  let(:expected_api_transaction_count_table) do
    [
      ['Week', 'True ID', 'Instant verify', 'Phone Finder', 'Socure (DocV)',
       'Fraud Score and Attribute', 'Threat Metrix'],
      ["#{time_range.begin.to_date} - #{time_range.end.to_date}", 10, 15, 20, 25, 30, 40],
    ]
  end

  subject(:report) { described_class.new(time_range:) }

  before do
    allow_any_instance_of(Reporting::CloudwatchClient).to receive(:fetch).and_return(mock_results)
    allow(report).to receive(:true_id_table).and_return([10, mock_results])
    allow(report).to receive(:instant_verify_table).and_return([15, mock_results])
    allow(report).to receive(:phone_finder_table).and_return([20, mock_results])
    allow(report).to receive(:socure_table).and_return([25, mock_results])
    allow(report).to receive(:fraud_score_and_attribute_table).and_return([30, mock_results])
    allow(report).to receive(:threat_metrix_table).and_return([40, mock_results])
  end

  describe '#api_transaction_count' do
    it 'returns an array with correct headers and values' do
      table = report.api_transaction_count

      expect(table).to be_an(Array)
      expect(table.size).to eq(2)

      header_row = table.first
      data_row = table.last

      expect(header_row).to eq(
        ['Week', 'True ID', 'Instant verify', 'Phone Finder', 'Socure (DocV)',
         'Fraud Score and Attribute', 'Threat Metrix'],
      )
      expect(data_row.first).to eq("#{time_range.begin.to_date} - #{time_range.end.to_date}")
      expect(data_row[1..]).to eq([10, 15, 20, 25, 30, 40])
    end
  end

  describe '#to_csvs' do
    it 'generates valid CSV output' do
      csvs = report.to_csvs

      expect(csvs).to be_an(Array)
      expect(csvs.size).to eq(1)

      csv = csvs.first
      expect(csv).to match(
        /
          Week,True\ ID,Instant\ verify,Phone\ Finder,  # Match the first part
          Socure\ \(DocV\),Fraud\ Score\ and\ Attribute, # Match the second part
          Threat\ Metrix                                 # Match the last part
        /x,
      )
      expect(csv).to include("#{time_range.begin.to_date} - #{time_range.end.to_date}")
    end
  end

  describe '#as_emailable_reports' do
    it 'returns a valid emailable report object' do
      reports = report.as_emailable_reports

      expect(reports).to be_an(Array)
      expect(reports.first).to be_a(Reporting::EmailableReport)
      expect(reports.first.filename).to eq('api_transaction_count_report')
      expect(reports.first.table).to eq(report.api_transaction_count)
    end
  end
end
