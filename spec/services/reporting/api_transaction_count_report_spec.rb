require 'rails_helper'

RSpec.describe Reporting::ApiTransactionCountReport, type: :service do
  describe '#api_transaction_report' do
    let(:report_date) { Time.zone.today }
    let(:service) { described_class.new(report_date) }

    it 'returns the expected report data' do
      result = service.api_transaction_report

      expect(result).to be_an(Array)
      expect(result).not_to be_empty
      expect(result.first).to eq(['Query Name', 'Result Count'])
    end
  end

  describe '#api_transaction_emailable_report' do
    let(:report_date) { Time.zone.today }
    let(:service) { described_class.new(report_date) }

    it 'returns an EmailableReport object' do
      result = service.api_transaction_emailable_report

      expect(result).to be_a(EmailableReport)
      expect(result.title).to eq('API Transaction Count Report (last 30 days)')
      expect(result.filename).to eq('api_transaction_count')
    end
  end
end
