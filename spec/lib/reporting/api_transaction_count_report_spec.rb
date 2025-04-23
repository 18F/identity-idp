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
       'Fraud Score and Attribute', 'Instant Verify', 'Threat Metrix'],
      ["#{time_range.begin.to_date} - #{time_range.end.to_date}", 10, 15, 20, 25, 30, 35, 40, 45],
    ]
  end

  subject(:report) { Reporting::ApiTransactionCountReport.new(time_range:) }

  before do
    allow_any_instance_of(Reporting::CloudwatchClient).to receive(:fetch).and_return(mock_results)
  end

  describe '#api_transaction_count' do
    it 'returns an array with correct headers and values' do
      table = report.api_transaction_count

      expect(table).to be_an(Array)
      expect(table.size).to eq(2)

      header_row = table.first
      data_row = table.last

      expect(header_row).to include('Week', 'True ID', 'Instant verify', 'Phone Finder')
      expect(data_row.first).to eq("#{time_range.begin.to_date} - #{time_range.end.to_date}")
      expect(data_row[1..].all? { |val| val.is_a?(Integer) || val.is_a?(Array) }).to be true
    end
  end

  describe '#to_csvs' do
    it 'generates valid CSV output' do
      csvs = report.to_csvs

      expect(csvs).to be_an(Array)
      expect(csvs.size).to eq(1)

      csv = csvs.first
      expect(csv).to include('Week,True ID,Instant verify')
      expect(csv).to include("#{time_range.begin.to_date} - #{time_range.end.to_date}")
    end
  end

  describe '#as_emailable_reports' do
    it 'returns a valid emailable report object' do
      reports = report.as_emailable_reports

      expect(reports.first).to be_a(Reporting::EmailableReport)
      expect(reports.first.title).to eq('API Transaction Count Report')
    end
  end
end
