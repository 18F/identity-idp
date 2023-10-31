require 'rails_helper'

RSpec.describe Reporting::ActiveUsersCountReport do
  let(:report_date) { Date.new(2023, 3, 1) }

  subject(:report) { Reporting::ActiveUsersCountReport.new(report_date) }
  let(:sp1) { create(:service_provider) }
  let(:sp2) { create(:service_provider) }

  before do
    travel_to report_date
  end

  describe '#active_users_count_emailable_report' do
    it 'returns a report for active user', aggregate_failures: true do
      create(
        :service_provider_identity,
        user_id: 1,
        service_provider_record: sp1,
        last_ial1_authenticated_at: report_date + 5.days,
      )
      create(
        :service_provider_identity,
        user_id: 1,
        service_provider_record: sp2,
        last_ial2_authenticated_at: report_date + 2.days,
      )

      create(
        :service_provider_identity,
        user_id: 2,
        service_provider_record: sp1,
        last_ial1_authenticated_at: report_date + 2.days,
      )

      create(
        :service_provider_identity,
        user_id: 3,
        service_provider_record: sp1,
        last_ial1_authenticated_at: Date.new(2022, 10, 1),
      )
      create(
        :service_provider_identity,
        user_id: 3,
        service_provider_record: sp2,
        last_ial2_authenticated_at: Date.new(2022, 10, 10),
      )

      create(
        :service_provider_identity,
        user_id: 4,
        service_provider_record: sp1,
        last_ial1_authenticated_at: Date.new(2022, 12, 1),
      )

      expected_table = [
        ['Active Users', 'IAL1', 'IDV', 'Total', 'Range start', 'Range end'],
        ['Current month', 1, 1, 2, Date.new(2023, 3, 1), Date.new(2023, 3, 31)],
        ['Fiscal year Q1', 1, 1, 2, Date.new(2022, 10, 1), Date.new(2022, 12, 31)],
        ['Fiscal year Q2 cumulative', 2, 2, 4, Date.new(2022, 10, 1), Date.new(2023, 3, 31)],
        ['Fiscal year Q3 cumulative', 2, 2, 4, Date.new(2022, 10, 1), Date.new(2023, 6, 30)],
        ['Fiscal year Q4 cumulative', 2, 2, 4, Date.new(2022, 10, 1), Date.new(2023, 9, 30)],
      ]

      emailable_report = report.active_users_count_emailable_report

      emailable_report.table.zip(expected_table).each do |actual, expected|
        expect(actual).to eq(expected)
      end

      expect(emailable_report.title).to eq('Active Users')
      expect(emailable_report.filename).to eq 'active_users_count'
    end
  end
end
