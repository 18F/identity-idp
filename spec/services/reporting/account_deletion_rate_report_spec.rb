require 'rails_helper'

RSpec.describe Reporting::AccountDeletionRateReport do
  let(:report_date) { Date.new(2021, 3, 1) }

  subject(:report) { Reporting::AccountDeletionRateReport.new(report_date) }

  before do
    travel_to report_date
  end

  describe '#account_deletion_report' do
    it 'returns a report with the total account deleted (last 30 days)' do
      account_deletion_table = report.account_deletion_report
      expected_account_deletion_table = [['Total account deleted (last 30 days)'], [0]]

      expect(account_deletion_table).to eq(expected_account_deletion_table)
    end
  end
end
