require 'rails_helper'

RSpec.describe Db::MonthlySpAuthCount::UniqueMonthlyAuthCountsByIaa do
  describe '.call' do
    let(:key) { 'iaa1-0001' }
    let(:iaa) do
      {
        key: key,
        start_date: 1.year.ago,
        end_date: Time.zone.now,
        issuers: [],
      }
    end

    subject(:results) do
      Db::MonthlySpAuthCount::UniqueMonthlyAuthCountsByIaa.call(**iaa)
    end

    it 'is empty with no data' do
      expect(results).to eq([])
    end

    context 'with data' do
      let(:iaa) do
        {
          key: key,
          start_date: iaa_range.begin,
          end_date: iaa_range.end,
          issuers: [issuer1, issuer2, issuer3],
        }
      end
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
          billable: true,
        )

        # non-billable event in partial month, should be ignored
        create(
          :sp_return_log,
          user_id: user1.id,
          issuer: issuer1,
          ial: 1,
          requested_at: inside_partial_month,
          returned_at: inside_partial_month,
          billable: false,
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
            billable: true,
          )
        end

        # 1 old user + 1 new user in whole month @ IAL 1
        [user1, user2].each do |user|
          10.times do
            create(
              :sp_return_log,
              user_id: user.id,
              ial: 1,
              issuer: issuer1,
              requested_at: inside_whole_month,
              returned_at: inside_whole_month,
              billable: true,
            )
          end
        end

        # 2 old user + 1 new user in whole month @ IAL 2
        [user1, user2, user3].each do |user|
          7.times do
            create(
              :sp_return_log,
              user_id: user.id,
              ial: 2,
              issuer: issuer2,
              requested_at: inside_whole_month,
              returned_at: inside_whole_month,
              billable: true,
            )
          end
        end
      end

      it 'adds up auth_counts and sp_return_log instances' do
        rows = [
          {
            ial: 1,
            key: key,
            year_month: '202009',
            iaa_start_date: iaa_range.begin.to_s,
            iaa_end_date: iaa_range.end.to_s,
            total_auth_count: 1,
            unique_users: 1,
            new_unique_users: 1,
          },
          {
            ial: 2,
            key: key,
            year_month: '202009',
            iaa_start_date: iaa_range.begin.to_s,
            iaa_end_date: iaa_range.end.to_s,
            total_auth_count: 2,
            unique_users: 2,
            new_unique_users: 2,
          },
          {
            ial: 1,
            key: key,
            year_month: '202010',
            iaa_start_date: iaa_range.begin.to_s,
            iaa_end_date: iaa_range.end.to_s,
            total_auth_count: 20,
            unique_users: 2,
            new_unique_users: 1,
          },
          {
            ial: 2,
            key: key,
            year_month: '202010',
            iaa_start_date: iaa_range.begin.to_s,
            iaa_end_date: iaa_range.end.to_s,
            total_auth_count: 21,
            unique_users: 3,
            new_unique_users: 1,
          },
        ]

        expect(results).to match_array(rows)
      end
    end

    context 'with only partial month data' do
      let(:iaa_range) { Date.new(2020, 9, 15)..Date.new(2020, 9, 17) }
      let(:issuer) { 'issuer1' }
      let(:rows) { [] }

      it 'adds up auth_counts and sp_return_log instances' do
        expect(results).to match_array(rows)
      end
    end
  end
end
