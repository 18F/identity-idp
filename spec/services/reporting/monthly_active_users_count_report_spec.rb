require 'rails_helper'

RSpec.describe Reporting::MonthlyActiveUsersCountReport do
  let(:report_date) { Date.new(2023, 3, 1) }

  subject(:report) { Reporting::MonthlyActiveUsersCountReport.new(report_date) }
  let(:sp1) { create(:service_provider) }
  let(:sp2) { create(:service_provider) }

  before do
    travel_to report_date
  end

  describe '#result' do
    it 'returns a report for monthly active user' do
      create(
        :service_provider_identity,
        user_id: 1,
        service_provider_record: sp1,
        last_ial1_authenticated_at: report_date - 5.days,
      )
      create(
        :service_provider_identity,
        user_id: 1,
        service_provider_record: sp2,
        last_ial2_authenticated_at: report_date - 2.days,
      )

      create(
        :service_provider_identity,
        user_id: 2,
        service_provider_record: sp1,
        last_ial1_authenticated_at: report_date - 2.days,
      )
      monthly_active_users_count_table = report.monthly_active_users_count_report

      expected_table = [
        ['Monthly Active Users', 'Value'],
        ['IAL1', 1],
        ['IDV', 1],
        ['Total', 2],
      ]

      expect(monthly_active_users_count_table).to eq(expected_table)

      emailable_report = report.monthly_active_users_count_emailable_report
      expect(emailable_report.title).to eq('February 2023 Active Users')
      expect(emailable_report.table).to eq monthly_active_users_count_table
      expect(emailable_report.filename).to eq 'monthly_active_users_count'
    end
  end
end
