require 'rails_helper'

RSpec.describe Reporting::AccountDeletionRateReport do
  let(:report_date) { Date.new(2021, 3, 1) }

  subject(:report) { Reporting::AccountDeletionRateReport.new(report_date) }

  before do
    travel_to report_date
  end

  describe '#account_deletion_report' do
    before do
      travel_to(report_date - 2.months) do
        create_and_delete_accounts
      end
      travel_to(report_date - 1.month) do
        create_and_delete_accounts
      end
      travel_to(report_date - 1.week) do
        create_and_delete_accounts
      end
    end

    it 'returns a report for account deletion rate (last 30 days)' do
      account_deletion_table = report.account_deletion_report
      expected_table = [['Deleted Users', 'Total Users', 'Deletion Rate'], [2, 8, 0.25]]

      expect(account_deletion_table).to eq(expected_table)
    end
  end

  def create_and_delete_accounts
    create(:user, :proofed)
    create_list(:user, 2)

    user = create(:user)
    DeletedUser.create_from_user(user)
    user.destroy!
  end
end
