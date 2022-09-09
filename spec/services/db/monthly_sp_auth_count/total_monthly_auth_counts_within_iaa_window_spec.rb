require 'rails_helper'

RSpec.describe Db::MonthlySpAuthCount::TotalMonthlyAuthCountsWithinIaaWindow do
  let(:iaa_range) { Date.new(2021, 1, 15)..Date.new(2022, 1, 14) }

  describe '.call' do
    subject(:result) do
      Db::MonthlySpAuthCount::TotalMonthlyAuthCountsWithinIaaWindow.call(
        issuer: service_provider.issuer,
        iaa_start_date: service_provider.iaa_start_date,
        iaa_end_date: service_provider.iaa_end_date,
        iaa: service_provider.iaa,
      )
    end

    context 'when the SP does not have IAA start/end dates' do
      let(:service_provider) { create(:service_provider, iaa_start_date: nil, iaa_end_date: nil) }

      it 'skips and returns an empty array' do
        expect(result).to eq([])
      end
    end

    let(:service_provider) do
      create(
        :service_provider,
        iaa_start_date: iaa_range.begin,
        iaa_end_date: iaa_range.end,
        iaa: SecureRandom.hex,
      )
    end

    it 'is empty with no data' do
      expect(result.to_a).to eq([])
    end

    context 'with data' do
      let(:partial_month_date) { iaa_range.begin + 1.day }
      let(:full_month_date) { iaa_range.begin + 1.month }
      let(:user) { create(:user) }

      before do
        # 2 IAL 1 auths during partial month
        2.times do
          create(
            :sp_return_log,
            user: user,
            ial: 1,
            service_provider: service_provider,
            requested_at: partial_month_date,
            returned_at: partial_month_date,
            billable: true,
          )
        end

        # non-billable event during partial month, should be ignored
        create(
          :sp_return_log,
          user: user,
          ial: 1,
          service_provider: service_provider,
          requested_at: partial_month_date,
          returned_at: partial_month_date,
          billable: false,
        )

        # 11 IAL 1 auths during full month
        11.times do
          create(
            :sp_return_log,
            user: user,
            service_provider: service_provider,
            ial: 1,
            requested_at: full_month_date,
            returned_at: full_month_date,
            billable: true,
          )
        end
      end

      it 'counts and uniques auths' do
        rows = [
          {
            year_month: partial_month_date.strftime('%Y%m'),
            ial: 1,
            issuer: service_provider.issuer,
            total_auth_count: 2,
            unique_users: 1,
            new_unique_users: 1,
            iaa: service_provider.iaa,
            iaa_start_date: iaa_range.begin.to_s,
            iaa_end_date: iaa_range.end.to_s,
          },
          {
            year_month: full_month_date.strftime('%Y%m'),
            ial: 1,
            issuer: service_provider.issuer,
            total_auth_count: 11,
            unique_users: 1,
            new_unique_users: 0,
            iaa: service_provider.iaa,
            iaa_start_date: iaa_range.begin.to_s,
            iaa_end_date: iaa_range.end.to_s,
          },
        ]

        expect(result).to match_array(rows)
      end
    end

    context 'with only partial months' do
      let(:iaa_range) { Date.new(2021, 1, 15)..Date.new(2021, 1, 17) }

      it 'counts and uniques auths' do
        expect(result).to match_array([])
      end
    end
  end
end
