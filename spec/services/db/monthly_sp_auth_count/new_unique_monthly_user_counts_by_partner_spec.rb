require 'rails_helper'

RSpec.describe Db::MonthlySpAuthCount::NewUniqueMonthlyUserCountsByPartner do
  def newest_profile(user)
    user.profiles.max_by(&:verified_at)
  end

  def oldest_profile(user)
    user.profiles.min_by(&:verified_at)
  end

  describe '.call' do
    subject(:results) do
      Db::MonthlySpAuthCount::NewUniqueMonthlyUserCountsByPartner.call(
        partner: partner_key,
        start_date: partner_range.begin,
        end_date: partner_range.end,
        issuers: issuers,
      )
    end

    context 'with no data no issuers' do
      let(:partner_key) { 'DHS' }
      let(:partner_range) { 1.year.ago..Time.zone.now }
      let(:issuers) { [] }

      it 'is empty with no data issuers' do
        expect(results).to eq([])
      end
    end

    context 'with no data no date range' do
      let(:partner_key) { 'DHS' }
      let(:partner_range) { nil...nil }
      let(:issuers) { ['DFH', 'DFFF'] }

      it 'is empty with no date range' do
        expect(results).to eq([])
      end
    end

    context 'with data' do
      let(:partner_key) { 'DHS' }
      let(:issuers) { [issuer1, issuer2, issuer3] }

      let(:partner_range) { DateTime.new(2020, 9, 15).utc..DateTime.new(2021, 9, 14).utc }
      let(:inside_partial_month) { DateTime.new(2020, 9, 16).utc }
      let(:inside_whole_month) { DateTime.new(2020, 10, 16).utc }

      let(:user1) { create(:user, profiles: [profile1a, profile1b]) }
      let(:profile1a) { build(:profile, verified_at: DateTime.new(2015, 9, 17).utc) }
      let(:profile1b) { build(:profile, verified_at: DateTime.new(2020, 9, 16).utc) }

      let(:user2) { create(:user, profiles: [profile2]) }
      let(:profile2) { build(:profile, verified_at: DateTime.new(2018, 12, 25).utc) }

      let(:user3) { create(:user, profiles: [profile3]) }
      let(:profile3) { build(:profile, verified_at: DateTime.new(2019, 11, 10).utc) }

      let(:user4) { create(:user, profiles: [profile4]) }
      let(:profile4) { build(:profile, verified_at: DateTime.new(2020, 3, 1).utc) }

      let(:user5) { create(:user, profiles: [profile5]) }
      let(:profile5) { build(:profile, verified_at: DateTime.new(2019, 4, 17).utc) }

      let(:user6) { create(:user, profiles: [profile6]) }
      let(:profile6) { build(:profile, verified_at: DateTime.new(2018, 9, 15).utc) }

      let(:user7) { create(:user, profiles: [profile7]) }
      let(:profile7) { build(:profile, verified_at: DateTime.new(2017, 2, 15).utc) }

      let(:user8) { create(:user, profiles: [profile8]) }
      let(:profile8) { build(:profile, verified_at: DateTime.new(2016, 3, 20).utc) }

      let(:user9) { create(:user, profiles: [profile9]) }
      let(:profile9) { build(:profile, verified_at: DateTime.new(2012, 12, 15).utc) }

      let(:user10) { create(:user, profiles: [profile10]) }
      let(:profile10) { build(:profile, verified_at: nil) }

      let(:user11) { create(:user, profiles: [profile11]) }
      let(:profile11) { build(:profile, verified_at: DateTime.new(2019, 10, 1).utc) }

      let(:user12) { create(:user, profiles: [profile12]) }
      let(:profile12) { build(:profile, verified_at: DateTime.new(2019, 10, 16).utc) }

      let(:user13) { create(:user, profiles: [profile13]) }
      let(:profile13) { build(:profile, verified_at: DateTime.new(2020, 9, 16).utc) }

      let(:issuer1) { 'issuer1' }
      let(:issuer2) { 'issuer2' }
      let(:issuer3) { 'issuer3' }
      let(:issuer4) { 'issuer4' }
      let(:issuer5) { 'issuer5' }

      before do
        # Inside partial month

        # non-billable event in partial month, should be ignored
        create(
          :sp_return_log,
          user_id: user1.id,
          issuer: issuer1,
          ial: 2,
          returned_at: inside_partial_month,
          profile_id: newest_profile(user1).id,
          profile_verified_at: newest_profile(user1).verified_at,
          billable: false,
        )

        # 2 unique user in partial month with different issuers
        [[user1, issuer1], [user2, issuer2]].each do |user, issuer|
          create(
            :sp_return_log,
            user_id: user.id,
            issuer: issuer,
            ial: 2,
            returned_at: inside_partial_month,
            profile_id: oldest_profile(user).id,
            profile_verified_at: oldest_profile(user).verified_at,
            billable: true,
          )
        end

        #  6 new users in partial month proofed in year 1-5
        [user4, user5, user6, user7, user8, user11].each do |user|
          create(
            :sp_return_log,
            user_id: user.id,
            ial: 2,
            issuer: issuer2,
            returned_at: inside_partial_month,
            profile_id: newest_profile(user).id,
            profile_verified_at: newest_profile(user).verified_at,
            billable: true,
          )
        end

        # Inside whole month

        # 5 old user + 1 new user in whole month
        [user1, user2, user3, user4, user5, user7].each do |user|
          2.times do
            create(
              :sp_return_log,
              user_id: user.id,
              ial: 2,
              issuer: issuer2,
              returned_at: inside_whole_month,
              profile_id: newest_profile(user).id,
              profile_verified_at: newest_profile(user).verified_at,
              billable: true,
            )
          end
        end

        # 2 new users nil profile verified and > 5 year bucket in partial month
        [user9, user10].each do |user|
          2.times do
            create(
              :sp_return_log,
              user_id: user.id,
              ial: 2,
              issuer: issuer1,
              returned_at: inside_whole_month,
              profile_id: newest_profile(user)&.id,
              profile_verified_at: newest_profile(user)&.verified_at,
              billable: true,
            )
          end
        end

        # 1 old user returning with new profile age in whole month
        [user6].each do |user|
          4.times do
            create(
              :sp_return_log,
              user_id: user.id,
              ial: 2,
              issuer: issuer2,
              returned_at: inside_whole_month,
              profile_id: newest_profile(user).id,
              profile_verified_at: newest_profile(user).verified_at,
              billable: true,
            )
          end
        end

        #  1 year1 user "upfront" in partial month
        [user13].each do |user|
          create(
            :sp_return_log,
            user_id: user.id,
            ial: 2,
            issuer: issuer3,
            returned_at: inside_partial_month,
            profile_id: newest_profile(user).id,
            profile_verified_at: newest_profile(user).verified_at,
            billable: true,
            profile_requested_issuer: issuer3,
          )
        end

        #  1 year1 user "existing" in partial month
        [user13].each do |user|
          create(
            :sp_return_log,
            user_id: user.id,
            ial: 2,
            issuer: issuer2,
            returned_at: inside_partial_month,
            profile_id: newest_profile(user).id,
            profile_verified_at: newest_profile(user).verified_at,
            billable: true,
            profile_requested_issuer: issuer3,
          )
        end

        # 1 old user with new profile in whole month
        [user1].each do |user|
          2.times do
            create(
              :sp_return_log,
              user_id: user.id,
              ial: 2,
              issuer: issuer2,
              returned_at: inside_whole_month,
              profile_id: oldest_profile(user1).id,
              profile_verified_at: oldest_profile(user1).verified_at,
              billable: true,
            )
          end
        end

        # 1 old user returns with a new profile age 2 inside whole month
        [user11].each do |user|
          2.times do
            create(
              :sp_return_log,
              user_id: user.id,
              ial: 2,
              issuer: issuer2,
              returned_at: inside_whole_month,
              profile_id: newest_profile(user).id,
              profile_verified_at: newest_profile(user).verified_at,
              billable: true,
            )
          end
        end

        # 1 new user signs in with profile age of 1 year and then signs in again later in same month
        # with profile age of 2 years
        [user12].each do |user|
          create(
            :sp_return_log,
            user_id: user.id,
            ial: 2,
            issuer: issuer2,
            returned_at: DateTime.new(2020, 10, 1).utc,
            profile_id: newest_profile(user).id,
            profile_verified_at: newest_profile(user).verified_at,
            billable: true,
          )
          create(
            :sp_return_log,
            user_id: user.id,
            ial: 2,
            issuer: issuer2,
            returned_at: DateTime.new(2020, 10, 30).utc,
            profile_id: newest_profile(user).id,
            profile_verified_at: newest_profile(user).verified_at,
            billable: true,
          )
        end

        # Outside analysis range
        # 1 new user returning outside the range of analysis
        [user11].each do |user, _profile|
          3.times do
            create(
              :sp_return_log,
              user_id: user.id,
              ial: 2,
              issuer: issuer2,
              returned_at: DateTime.new(2022, 10, 5).utc,
              profile_id: user.profiles[0].id,
              profile_verified_at: user.profiles[0].verified_at,
              billable: true,
            )
          end
        end
      end

      # rubocop:disable Layout/LineLength
      it 'adds up new unique users from sp_return_log instances and splits based on profile age' do
        rows = [
          {
            partner: partner_key,
            issuers: issuers,
            year_month: '202009',
            iaa_start_date: partner_range.begin.to_s,
            iaa_end_date: partner_range.end.to_s,
            unique_user_proofed_events: 10,
            partner_ial2_unique_user_events_year1: 4,
            partner_ial2_unique_user_events_year2: 2,
            partner_ial2_unique_user_events_year3: 1,
            partner_ial2_unique_user_events_year4: 1,
            partner_ial2_unique_user_events_year5: 2,
            partner_ial2_unique_user_events_year_greater_than_5: 0,
            partner_ial2_unique_user_events_unknown: 0,
            new_unique_user_proofed_events: 10,
            partner_ial2_new_unique_user_events_year1_upfront: 1,
            partner_ial2_new_unique_user_events_year1_existing: 3,
            partner_ial2_new_unique_user_events_year1: 4, # Note that year_1 = year_1_upfront + year_1_existing
            partner_ial2_new_unique_user_events_year2: 2,
            partner_ial2_new_unique_user_events_year3: 1,
            partner_ial2_new_unique_user_events_year4: 1,
            partner_ial2_new_unique_user_events_year5: 2,
            partner_ial2_new_unique_user_events_year_greater_than_5: 0,
            partner_ial2_new_unique_user_events_unknown: 0,
            partner_ial2_unique_user_events_delegated_only: 0,
            partner_ial2_unique_user_events_delegated_proofing: 0,
          },
          {
            partner: partner_key,
            issuers: issuers,
            year_month: '202010',
            iaa_start_date: partner_range.begin.to_s,
            iaa_end_date: partner_range.end.to_s,
            unique_user_proofed_events: 13,
            partner_ial2_unique_user_events_year1: 4,
            partner_ial2_unique_user_events_year2: 4,
            partner_ial2_unique_user_events_year3: 1,
            partner_ial2_unique_user_events_year4: 1,
            partner_ial2_unique_user_events_year5: 0,
            partner_ial2_unique_user_events_year_greater_than_5: 2,
            partner_ial2_unique_user_events_unknown: 1,
            new_unique_user_proofed_events: 8,
            partner_ial2_new_unique_user_events_year1_upfront: 0,
            partner_ial2_new_unique_user_events_year1_existing: 3,
            partner_ial2_new_unique_user_events_year1: 3, # Note that year_1 = year_1_upfront + year_1_existing
            partner_ial2_new_unique_user_events_year2: 2,
            partner_ial2_new_unique_user_events_year3: 0,
            partner_ial2_new_unique_user_events_year4: 0,
            partner_ial2_new_unique_user_events_year5: 0,
            partner_ial2_new_unique_user_events_year_greater_than_5: 2,
            partner_ial2_new_unique_user_events_unknown: 1,
            partner_ial2_unique_user_events_delegated_only: 0,
            partner_ial2_unique_user_events_delegated_proofing: 0,
          },
        ]
        expect(results).to match_array(rows)
      end
    end
    # rubocop:enable Layout/LineLength

    context 'with a delegated row' do
      let(:partner_key) { 'HOUSING' }
      let(:partner_range) { Date.new(2020, 9, 1)..Date.new(2021, 8, 31) }
      let(:agency_issuer) { 'urn:gov:gsa:openidconnect:sp:housing_records' }
      let(:sp_issuer) { 'urn:gov:gsa:openidconnect:sp:mybenefits' }
      let(:issuers) { [agency_issuer] }
      let(:profile) { build(:profile, verified_at: DateTime.new(2020, 10, 1).utc) }
      let(:user) { create(:user, profiles: [profile]) }
      let(:proofed_in_session) { true }
      let(:grant) { create(:token_exchange_grant, user:, proofed_in_session:) }
      let(:october) { results.find { |row| row[:year_month] == '202010' } }

      def create_row(returned_at:, access_type:, token: nil)
        row = create(
          :sp_return_log, user_id: user.id, issuer: agency_issuer, ial: 2, billable: true,
                          returned_at:, profile_id: profile.id,
                          profile_verified_at: profile.verified_at,
                          profile_requested_issuer: sp_issuer, access_type:
        )
        if token
          SpReturnLogBillingAdjustment.create!(
            sp_return_log: row, adjustment_type: :delegated_token_issued,
            token_exchange_token: token
          )
        end
        row
      end

      before do
        create_row(
          returned_at: DateTime.new(2020, 10, 5).utc, access_type: 'delegated',
          token: create(:token_exchange_token, grant:)
        )
      end

      it 'counts the person once, as upfront for the agency, and breaks the facts out' do
        expect(results.length).to eq(1)
        expect(october).to include(
          unique_user_proofed_events: 1,
          new_unique_user_proofed_events: 1,
          partner_ial2_new_unique_user_events_year1_upfront: 1,
          partner_ial2_new_unique_user_events_year1_existing: 0,
          partner_ial2_unique_user_events_delegated_only: 1,
          partner_ial2_unique_user_events_delegated_proofing: 1,
        )
      end

      context 'when the person was verified before the delegating sign-in' do
        let(:proofed_in_session) { false }

        it 'is an existing profile for the agency' do
          expect(october).to include(
            partner_ial2_new_unique_user_events_year1_upfront: 0,
            partner_ial2_new_unique_user_events_year1_existing: 1,
            partner_ial2_unique_user_events_delegated_only: 1,
            partner_ial2_unique_user_events_delegated_proofing: 0,
          )
        end
      end

      it 'keeps how the person arrived off the per-user key' do
        expect(described_class::UserVerifiedKey.members)
          .to eq(%i[user_id profile_id profile_age is_upfront])
        sql = described_class.build_queries(
          issuers:, months: [partner_range.begin...partner_range.begin.end_of_month],
        ).first
        expect(sql).to include("COALESCE(sp_return_logs.access_type, 'direct') AS access_type")
        expect(sql).to include('grants.proofed_in_session = true')
        expect(sql).to include('NOT EXISTS')
      end

      context 'when the same person also signed in to the agency directly that month' do
        before { create_row(returned_at: DateTime.new(2020, 10, 7).utc, access_type: 'direct') }

        it 'counts one person, not one per way of arriving, and not as delegated-only' do
          expect(october).to include(
            unique_user_proofed_events: 1,
            new_unique_user_proofed_events: 1,
            partner_ial2_new_unique_user_events_year1_upfront: 1,
            partner_ial2_unique_user_events_delegated_only: 0,
            partner_ial2_unique_user_events_delegated_proofing: 1,
          )
        end
      end

      context 'when the person signed in directly in an earlier month' do
        before { create_row(returned_at: DateTime.new(2020, 10, 2).utc, access_type: 'direct') }
        let(:profile) { build(:profile, verified_at: DateTime.new(2020, 9, 10).utc) }

        before do
          # The direct sign-in is in September; the delegated row (created above) in October.
          SpReturnLog.where(access_type: 'direct').update_all(
            returned_at: DateTime.new(
              2020, 9,
              20
            ).utc,
          )
        end

        it 'does not count the delegated month as a new user' do
          expect(october).to include(
            unique_user_proofed_events: 1,
            new_unique_user_proofed_events: 0,
            partner_ial2_unique_user_events_delegated_only: 1,
          )
        end
      end

      context 'with a sign-in row an exchange excluded from billing' do
        before do
          excluded = create_row(returned_at: DateTime.new(2020, 11, 3).utc, access_type: 'direct')
          SpReturnLogBillingAdjustment.create!(
            sp_return_log: excluded, adjustment_type: :exclude_from_billing,
          )
        end

        it 'leaves the excluded row out' do
          expect(results.map { |row| row[:year_month] }).to eq(['202010'])
        end
      end
    end

    context 'with only partial month data' do
      let(:partner_key) { 'DHS' }
      let(:partner_range) { Date.new(2020, 9, 15)..Date.new(2020, 9, 17) }
      let(:issuers) { ['issuer1'] }
      let(:rows) { [] }

      it 'adds up auth_counts and sp_return_log instances' do
        expect(results).to match_array(rows)
      end
    end

    context 'with user having multiple profiles with different upfront/existing status' do
      let(:partner_key) { 'HHS-PSC' }
      let(:partner_range) { Date.new(2025, 7, 1)..Date.new(2025, 7, 31) }
      let(:issuers) { [issuer_a, issuer_b] }
      let(:issuer_a) { 'issuer_a' }
      let(:issuer_b) { 'issuer_b' }

      let(:user_multi_profile) { create(:user, profiles: [profile1, profile2]) }
      let(:profile1) { build(:profile, verified_at: DateTime.new(2025, 7, 1).utc) }
      let(:profile2) { build(:profile, verified_at: DateTime.new(2025, 7, 2).utc) }

      let(:user_upfront) { create(:user, profiles: [profile_upfront]) }
      let(:profile_upfront) { build(:profile, verified_at: DateTime.new(2025, 7, 3).utc) }

      let(:user_existing) { create(:user, profiles: [profile_existing]) }
      let(:profile_existing) { build(:profile, verified_at: DateTime.new(2025, 7, 4).utc) }

      before do
        create(
          :sp_return_log,
          user_id: user_multi_profile.id,
          issuer: issuer_a,
          profile_requested_issuer: issuer_a,
          ial: 2,
          returned_at: DateTime.new(2025, 7, 15).utc,
          profile_id: profile1.id,
          profile_verified_at: profile1.verified_at,
          billable: true,
        )

        create(
          :sp_return_log,
          user_id: user_multi_profile.id,
          issuer: issuer_b,
          profile_requested_issuer: issuer_a,
          ial: 2,
          returned_at: DateTime.new(2025, 7, 16).utc,
          profile_id: profile2.id,
          profile_verified_at: profile2.verified_at,
          billable: true,
        )

        create(
          :sp_return_log,
          user_id: user_upfront.id,
          issuer: issuer_a,
          profile_requested_issuer: issuer_a,
          ial: 2,
          returned_at: DateTime.new(2025, 7, 17).utc,
          profile_id: profile_upfront.id,
          profile_verified_at: profile_upfront.verified_at,
          billable: true,
        )

        create(
          :sp_return_log,
          user_id: user_existing.id,
          issuer: issuer_b,
          profile_requested_issuer: issuer_a,
          ial: 2,
          returned_at: DateTime.new(2025, 7, 18).utc,
          profile_id: profile_existing.id,
          profile_verified_at: profile_existing.verified_at,
          billable: true,
        )
      end

      it 'classifies each profile event independently' do
        expect(results.length).to eq(1)
        july_result = results.first

        expect(july_result[:unique_user_proofed_events]).to eq(4)
        expect(july_result[:partner_ial2_unique_user_events_year1]).to eq(4)
        expect(july_result[:new_unique_user_proofed_events]).to eq(4)

        expect(july_result[:partner_ial2_new_unique_user_events_year1_upfront]).to eq(2)
        expect(july_result[:partner_ial2_new_unique_user_events_year1_existing]).to eq(2)

        upfront = july_result[:partner_ial2_new_unique_user_events_year1_upfront]
        existing = july_result[:partner_ial2_new_unique_user_events_year1_existing]
        total = july_result[:partner_ial2_new_unique_user_events_year1]
        expect(upfront + existing).to eq(total)
      end
    end

    context 'with user having multiple upfront profiles in same month' do
      let(:partner_key) { 'TEST' }
      let(:partner_range) { Date.new(2025, 8, 1)..Date.new(2025, 8, 31) }
      let(:issuers) { [issuer_a, issuer_b] }
      let(:issuer_a) { 'issuer_a' }
      let(:issuer_b) { 'issuer_b' }

      let(:user_double_upfront) { create(:user, profiles: [profile1, profile2]) }
      let(:profile1) { build(:profile, verified_at: DateTime.new(2025, 8, 1).utc) }
      let(:profile2) { build(:profile, verified_at: DateTime.new(2025, 8, 2).utc) }

      let(:user_single_upfront) { create(:user, profiles: [profile3]) }
      let(:profile3) { build(:profile, verified_at: DateTime.new(2025, 8, 3).utc) }

      before do
        create(
          :sp_return_log,
          user_id: user_double_upfront.id,
          issuer: issuer_a,
          profile_requested_issuer: issuer_a,
          ial: 2,
          returned_at: DateTime.new(2025, 8, 15).utc,
          profile_id: profile1.id,
          profile_verified_at: profile1.verified_at,
          billable: true,
        )

        create(
          :sp_return_log,
          user_id: user_double_upfront.id,
          issuer: issuer_b,
          profile_requested_issuer: issuer_b,
          ial: 2,
          returned_at: DateTime.new(2025, 8, 16).utc,
          profile_id: profile2.id,
          profile_verified_at: profile2.verified_at,
          billable: true,
        )

        create(
          :sp_return_log,
          user_id: user_single_upfront.id,
          issuer: issuer_a,
          profile_requested_issuer: issuer_a,
          ial: 2,
          returned_at: DateTime.new(2025, 8, 17).utc,
          profile_id: profile3.id,
          profile_verified_at: profile3.verified_at,
          billable: true,
        )
      end

      it 'counts each unique profile as upfront when issuer matches profile_requested_issuer' do
        expect(results.length).to eq(1)
        august_result = results.first

        expect(august_result[:unique_user_proofed_events]).to eq(3)
        expect(august_result[:new_unique_user_proofed_events]).to eq(3)

        # Each profile is counted separately - user_double_upfront has 2 upfront profiles,
        # user_single_upfront has 1, so total is 3
        expect(august_result[:partner_ial2_new_unique_user_events_year1_upfront]).to eq(3)
        expect(august_result[:partner_ial2_new_unique_user_events_year1_existing]).to eq(0)
        expect(august_result[:partner_ial2_new_unique_user_events_year1]).to eq(3)

        upfront = august_result[:partner_ial2_new_unique_user_events_year1_upfront]
        existing = august_result[:partner_ial2_new_unique_user_events_year1_existing]
        total = august_result[:partner_ial2_new_unique_user_events_year1]
        expect(upfront + existing).to eq(total)
      end
    end
  end
end
