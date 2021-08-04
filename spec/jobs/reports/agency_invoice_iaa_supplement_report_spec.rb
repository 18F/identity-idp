require 'rails_helper'

RSpec.describe Reports::AgencyInvoiceIaaSupplementReport do
  subject(:report) { Reports::AgencyInvoiceIaaSupplementReport.new }

  describe '#perform' do
    it 'is empty with no data' do
      expect(report.perform).to eq('[]')
    end

    context 'with data' do
      let(:iaa1) { 'iaa1' }
      let(:iaa1_range) { Date.new(2020, 4, 15)..Date.new(2021, 4, 14) }
      let(:inside_iaa1) { iaa1_range.begin + 1.day }

      let(:iaa2) { 'iaa2' }
      let(:iaa2_range) { Date.new(2020, 9, 1)..Date.new(2021, 8, 30) }
      let(:inside_iaa2) { iaa2_range.begin + 1.day }

      let(:user1) { create(:user) }
      let(:user2) { create(:user) }

      let!(:iaa1_sp) do
        create(
          :service_provider,
          iaa: iaa1,
          iaa_start_date: iaa1_range.begin,
          iaa_end_date: iaa1_range.end,
        )
      end

      let!(:iaa2_sp) do
        create(
          :service_provider,
          iaa: iaa2,
          iaa_start_date: iaa2_range.begin,
          iaa_end_date: iaa2_range.end,
        )
      end

      before do
        # 1 unique user in partial month at IAA 1 @ IAL 1
        create(
          :sp_return_log,
          user_id: user1.id,
          issuer: iaa1_sp.issuer,
          ial: 1,
          requested_at: inside_iaa1,
          returned_at: inside_iaa1,
        )

        # 1 unique user in month 1 at IAA 2 @ IAL 2
        create(
          :monthly_sp_auth_count,
          user_id: user1.id,
          auth_count: 1,
          ial: 2,
          issuer: iaa2_sp.issuer,
          year_month: inside_iaa2.strftime('%Y%m'),
        )

        # 2 users, each 2 auths (1 unique) in month 2 at IAA 2 @ IAL 2
        [user1, user2].each do |user|
          create(
            :monthly_sp_auth_count,
            user_id: user.id,
            auth_count: 2,
            ial: 2,
            issuer: iaa2_sp.issuer,
            year_month: (inside_iaa2 + 1.month).strftime('%Y%m'),
          )
        end
      end

      it 'counts up costs by issuer + ial, and includes iaa and app_id' do
        results = JSON.parse(report.perform, symbolize_names: true)

        rows = [
          {
            iaa: iaa1,
            ial1_total_auth_count: 1,
            ial2_total_auth_count: 0,
            ial1_unique_users: 1,
            ial2_unique_users: 0,
            ial1_new_unique_users: 1,
            ial2_new_unique_users: 0,
            year_month: inside_iaa1.strftime('%Y%m'),
            iaa_start_date: iaa1_range.begin.to_s,
            iaa_end_date: iaa1_range.end.to_s,
          },
          {
            iaa: iaa2,
            ial1_total_auth_count: 0,
            ial2_total_auth_count: 1,
            ial1_unique_users: 0,
            ial2_unique_users: 1,
            ial1_new_unique_users: 0,
            ial2_new_unique_users: 1,
            year_month: inside_iaa2.strftime('%Y%m'),
            iaa_start_date: iaa2_range.begin.to_s,
            iaa_end_date: iaa2_range.end.to_s,
          },
          {
            iaa: iaa2,
            ial1_total_auth_count: 0,
            ial2_total_auth_count: 4,
            ial1_unique_users: 0,
            ial2_unique_users: 2,
            ial1_new_unique_users: 0,
            ial2_new_unique_users: 1,
            year_month: (inside_iaa2 + 1.month).strftime('%Y%m'),
            iaa_start_date: iaa2_range.begin.to_s,
            iaa_end_date: iaa2_range.end.to_s,
          },
        ]

        expect(results).to match_array(rows)
      end
    end
  end
end
