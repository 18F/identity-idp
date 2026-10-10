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

    context 'missing data' do
      let(:iaa_range) { nil...nil }
      let(:iaa) do
        {
          key: key,
          start_date: iaa_range.begin,
          end_date: iaa_range.end,
          issuers: ['DHS', 'DHF'],
        }
      end

      it 'is empty with data no date range' do
        expect(results).to eq([])
      end
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
          returned_at: inside_partial_month,
          billable: true,
        )

        # non-billable event in partial month, should be ignored
        create(
          :sp_return_log,
          user_id: user1.id,
          issuer: issuer1,
          ial: 1,
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
            delegated_only_unique_users: 0,
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
            delegated_only_unique_users: 0,
          },
          {
            ial: :all,
            key: key,
            year_month: '202009',
            iaa_start_date: iaa_range.begin.to_s,
            iaa_end_date: iaa_range.end.to_s,
            unique_users: 2,
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
            delegated_only_unique_users: 0,
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
            delegated_only_unique_users: 0,
          },
          {
            ial: :all,
            key: key,
            year_month: '202010',
            iaa_start_date: iaa_range.begin.to_s,
            iaa_end_date: iaa_range.end.to_s,
            unique_users: 3,
          },
        ]

        expect(results).to match_array(rows)
      end
    end

    context 'with delegated rows' do
      let(:iaa_range) { Date.new(2020, 9, 1)..Date.new(2021, 8, 31) }
      let(:issuer) { 'urn:gov:gsa:openidconnect:sp:housing_records' }
      let(:user) { create(:user) }
      let(:iaa) do
        { key: key, start_date: iaa_range.begin, end_date: iaa_range.end, issuers: [issuer] }
      end
      let(:ial2_row) { results.find { |row| row[:ial] == 2 } }

      before do
        create(
          :service_provider, iaa:, issuer:, iaa_start_date: iaa_range.begin,
                             iaa_end_date: iaa_range.end
        )
      end

      context 'with a direct row and a delegated row for the same user in one month' do
        before do
          # The person signed in to the agency's own application...
          create(
            :sp_return_log, user_id: user.id, issuer:, ial: 2, billable: true,
                            returned_at: Date.new(2020, 10, 5), access_type: 'direct'
          )
          # ...and a service provider also exchanged a token for the agency's API that month.
          create(
            :sp_return_log, user_id: user.id, issuer:, ial: 2, billable: true,
                            returned_at: Date.new(2020, 10, 20), access_type: 'delegated'
          )
        end

        it 'bills one user while counting both rows, not as delegated-only' do
          expect(ial2_row).to include(
            total_auth_count: 2, unique_users: 1, new_unique_users: 1,
            delegated_only_unique_users: 0
          )
          expect(results.find { |row| row[:ial] == :all }).to include(unique_users: 1)
        end
      end

      context 'with a user who reached the agency only by delegation in the month' do
        before do
          create(
            :sp_return_log, user_id: user.id, issuer:, ial: 2, billable: true,
                            returned_at: Date.new(2020, 10, 20), access_type: 'delegated'
          )
        end

        it 'bills the user once and reports them as delegated-only' do
          expect(ial2_row).to include(
            unique_users: 1, new_unique_users: 1, delegated_only_unique_users: 1,
          )
        end
      end

      context 'with a sign-in row an exchange excluded from billing' do
        before do
          excluded = create(
            :sp_return_log, user_id: user.id, issuer:, ial: 2, billable: true,
                            returned_at: Date.new(2020, 10, 5)
          )
          SpReturnLogBillingAdjustment.create!(
            sp_return_log: excluded, adjustment_type: :exclude_from_billing,
          )
          # Two exclusions for one row (two agencies billed instead) still exclude it once.
          SpReturnLogBillingAdjustment.create!(
            sp_return_log: excluded, adjustment_type: :exclude_from_billing,
          )
          create(
            :sp_return_log, user_id: create(:user).id, issuer:, ial: 2, billable: true,
                            returned_at: Date.new(2020, 10, 6)
          )
        end

        it 'leaves the excluded row out' do
          expect(ial2_row).to include(total_auth_count: 1, unique_users: 1)
        end
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
