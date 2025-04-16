# frozen_string_literal: true

require 'rails_helper'
require 'reporting/api_transaction_count_report'

RSpec.describe Reporting::ApiTransactionCountReport do
  let(:mock_time_range) do
    Time.zone.parse('2024-04-01')..Time.zone.parse('2024-04-07')
  end

  let(:mock_results) { Array.new(5) { { id: SecureRandom.uuid } } }

  subject(:report) { described_class.new(time_range: mock_time_range) }

  before do
    allow_any_instance_of(Reporting::CloudwatchClient).to receive(:fetch).and_return(mock_results)
  end

  # describe '#api_transaction_count' do
  #   it 'returns an array with correct headers and values' do
  #     table = report.api_transaction_count

  #     expect(table).to be_an(Array)
  #     expect(table.size).to eq(2)

  #     header_row = table.first
  #     data_row = table.last

  #     expect(header_row).to include('Week', 'True ID', 'Instant verify', 'Phone Finder', 'Acuant')
  #     expect(data_row.first).to eq('2024-04-01 - 2024-04-07')
  #     expect(data_row[1..].all? { |val| val.is_a?(Integer) || val.is_a?(Array) }).to be true
  #   end
  # end

  describe '#to_csvs' do
    it 'generates valid CSV output' do
      csvs = report.to_csvs

      expect(csvs).to be_an(Array)
      expect(csvs.size).to eq(1)

      csv = csvs.first
      expect(csv).to include('Week', 'True ID', 'Instant verify')
      expect(csv).to include('2024-04-01 - 2024-04-07')
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
