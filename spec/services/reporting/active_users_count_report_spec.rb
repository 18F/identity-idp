require 'rails_helper'

RSpec.describe Reporting::ActiveUsersCountReport do
  let(:report_date) { Date.new(2023, 3, 1) }

  subject(:report) { Reporting::ActiveUsersCountReport.new(report_date) }
  let(:sp1) { create(:service_provider) }
  let(:sp2) { create(:service_provider) }

  before do
    travel_to report_date
  end

  describe '#result' do
    it 'returns a report for active user' do
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

      active_users_count_table = report.generate_report

      expected_table = [
        ['Active Users', 'IAL1', 'IDV', 'Total', 'Range start', 'Range end'],
        [
          'Monthly February 2023',
          1,
          1,
          2,
          Date.new(2023, 2, 1),
          Date.new(2023, 2, 28),
        ],
        [
          'Fiscal Year 2023',
          2,
          2,
          4,
          Date.new(2022, 10, 1),
          Date.new(2023, 9, 30),
        ],
      ]

      expect(active_users_count_table).to eq(expected_table)

      emailable_report = report.active_users_count_emailable_report
      expect(emailable_report.title).to eq('Active Users')
      expect(emailable_report.table).to eq active_users_count_table
      expect(emailable_report.filename).to eq 'active_users_count'
    end
  end
end
