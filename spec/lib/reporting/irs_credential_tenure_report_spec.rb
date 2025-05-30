require 'rails_helper'

RSpec.describe Reporting::IrsCredentialTenureReport do
  let(:report_date) { Date.new(2025, 5, 31) }
  subject(:report) { described_class.new(report_date) }

  describe '#total_user_count' do
    it 'returns the total number of users' do
      create_list(:user, 3)
      expect(report.send(:total_user_count)).to eq(3)
    end
  end

  describe '#average_credential_tenure_months' do
    it 'returns a numeric value' do
      create(:user, created_at: report_date - 2.months)
      create(:user, created_at: report_date - 4.months)
      expect(report.send(:average_credential_tenure_months)).to be_a(Numeric)
    end
  end

  describe '#irs_credential_tenure_report_report' do
    it 'returns a table with headers and values' do
      table = report.irs_credential_tenure_report_report
      expect(table.first).to include('Metric', 'Value')
      expect(table.last.first).to eq('Credential Tenure')
    end
  end
end