require 'rails_helper'

RSpec.describe Reports::AgencyInvoiceIssuerSupplementReport do
  subject(:report) { Reports::AgencyInvoiceIssuerSupplementReport.new }

  describe '#perform' do
    it 'is empty with no data' do
      expect(report.perform(Time.zone.today)).to eq('[]')
    end

    context 'with data' do
      let(:user) { create(:user) }
      let(:iaa_range) { Date.new(2021, 1, 1)..Date.new(2021, 12, 31) }
      let(:sp) do
        create(
          :service_provider,
          iaa: SecureRandom.hex,
          iaa_start_date: iaa_range.begin,
          iaa_end_date: iaa_range.end,
        )
      end

      before do
        3.times do
          create(
            :sp_return_log,
            user: user,
            service_provider: sp,
            ial: 1,
            requested_at: iaa_range.begin + 1.day,
            returned_at: iaa_range.begin + 1.day,
            billable: true,
          )
        end
        4.times do
          create(
            :sp_return_log,
            user: user,
            service_provider: sp,
            ial: 2,
            requested_at: iaa_range.begin + 1.day,
            returned_at: iaa_range.begin + 1.day,
            billable: true,
          )
        end
      end

      it 'totals up auth counts within IAA window by month' do
        result = JSON.parse(report.perform(Time.zone.today), symbolize_names: true)

        expect(result).to eq(
          [
            {
              issuer: sp.issuer,
              iaa: sp.iaa,
              iaa_start_date: '2021-01-01',
              iaa_end_date: '2021-12-31',
              year_month: '202101',
              ial1_total_auth_count: 3,
              ial2_total_auth_count: 4,
              ial1_unique_users: 1,
              ial2_unique_users: 1,
            },
          ],
        )
      end
    end
  end
end
