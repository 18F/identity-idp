require 'rails_helper'

RSpec.describe Db::MonthlySpAuthCount::UniqueMonthlyAuthCountsByIaa do
  describe '.call' do
    let(:iaa) { 'iaa1' }

    subject(:results) do
      Db::MonthlySpAuthCount::UniqueMonthlyAuthCountsByIaa.call(iaa)
    end

    it 'is empty with no data' do
      expect(results).to eq([])
    end

    context 'with data' do
      let(:iaa_range) { Date.new(2020, 9, 15)..Date.new(2021, 9, 14) }
      let(:inside_partial_month) { Date.new(2020, 9, 16) }
      let(:inside_whole_month) { Date.new(2020, 10, 16) }

      let(:user1) { create(:user) }
      let(:user2) { create(:user) }
      let(:user3) { create(:user) }
      let(:issuer1) { 'issuer1' }
      let(:issuer2) { 'issuer2' }
      let(:issuer3) { 'issuer3' }

      let!(:sps) do
        [issuer1, issuer2, issuer3].map do |issuer|
          create(
            :service_provider,
            iaa: iaa,
            issuer: issuer,
            iaa_start_date: iaa_range.begin,
            iaa_end_date: iaa_range.end,
          )
        end
      end

      before do
        # 1 unique user in partial month @ IAL1
        create(
          :sp_return_log,
          user_id: user1.id,
          issuer: issuer1,
          ial: 1,
          requested_at: inside_partial_month,
          returned_at: inside_partial_month,
        )

        # 2 unique user in partial month @ IAL2
        [user1, user2].each do |user|
          create(
            :sp_return_log,
            user_id: user.id,
            issuer: issuer2,
            ial: 2,
            requested_at: inside_partial_month,
            returned_at: inside_partial_month,
          )
        end

        # 1 old user + 1 new user in whole month @ IAL 1
        [user1, user2].each do |user|
          create(
            :monthly_sp_auth_count,
            user_id: user.id,
            auth_count: 1,
            ial: 1,
            issuer: issuer1,
            year_month: inside_whole_month.strftime('%Y%m'),
          )
        end

        # 2 old user + 1 new user in whole month @ IAL 2
        [user1, user2, user3].each do |user|
          create(
            :monthly_sp_auth_count,
            user_id: user.id,
            auth_count: 1,
            ial: 2,
            issuer: issuer2,
            year_month: inside_whole_month.strftime('%Y%m'),
          )
        end
      end

      it 'counts up costs by iaa' do
        rows = [
          {
            ial: 1,
            iaa: iaa,
            year_month: '202009',
            unique_users: 1,
            iaa_start_date: iaa_range.begin.to_s,
            iaa_end_date: iaa_range.end.to_s,
          },
          {
            ial: 2,
            iaa: iaa,
            year_month: '202009',
            unique_users: 2,
            iaa_start_date: iaa_range.begin.to_s,
            iaa_end_date: iaa_range.end.to_s,
          },
          {
            ial: 1,
            iaa: iaa,
            year_month: '202010',
            unique_users: 1,
            iaa_start_date: iaa_range.begin.to_s,
            iaa_end_date: iaa_range.end.to_s,
          },
          {
            ial: 2,
            iaa: iaa,
            year_month: '202010',
            unique_users: 1,
            iaa_start_date: iaa_range.begin.to_s,
            iaa_end_date: iaa_range.end.to_s,
          },
        ]

        expect(results.map(&:symbolize_keys)).to match_array(rows)
      end
    end
  end
end