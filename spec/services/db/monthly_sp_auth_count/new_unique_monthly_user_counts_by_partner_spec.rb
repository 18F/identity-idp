require 'rails_helper'

RSpec.describe Db::MonthlySpAuthCount::NewUniqueMonthlyUserCountsByPartner do
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
          requested_at: inside_partial_month,
          returned_at: inside_partial_month,
          profile_verified_at: user1.profiles.map(&:verified_at).max,
          billable: false,
        )

        # 2 unique user in partial month with different issuers
        [[user1, issuer1], [user2, issuer2]].each do |user, issuer|
          create(
            :sp_return_log,
            user_id: user.id,
            issuer: issuer,
            ial: 2,
            requested_at: inside_partial_month,
            returned_at: inside_partial_month,
            profile_verified_at: user.profiles.map(&:verified_at).min,
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
            requested_at: inside_partial_month,
            returned_at: inside_partial_month,
            profile_verified_at: user.profiles.map(&:verified_at).max,
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
              requested_at: inside_whole_month,
              returned_at: inside_whole_month,
              profile_verified_at: user.profiles.map(&:verified_at).max,
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
              requested_at: inside_whole_month,
              returned_at: inside_whole_month,
              profile_verified_at: user.profiles.map(&:verified_at).max,
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
              requested_at: inside_whole_month,
              returned_at: inside_whole_month,
              profile_verified_at: user.profiles.map(&:verified_at).max,
              billable: true,
            )
          end
        end

        # 1 old user with new profile in whole month
        [user1].each do |user|
          2.times do
            create(
              :sp_return_log,
              user_id: user.id,
              ial: 2,
              issuer: issuer2,
              requested_at: inside_whole_month,
              returned_at: inside_whole_month,
              profile_verified_at: user1.profiles.map(&:verified_at).min,
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
              requested_at: inside_whole_month,
              returned_at: inside_whole_month,
              profile_verified_at: user.profiles.map(&:verified_at).max,
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
            requested_at: inside_whole_month,
            returned_at: DateTime.new(2020, 10, 1).utc,
            profile_verified_at: user.profiles.map(&:verified_at).max,
            billable: true,
          )
          create(
            :sp_return_log,
            user_id: user.id,
            ial: 2,
            issuer: issuer2,
            requested_at: inside_whole_month,
            returned_at: DateTime.new(2020, 10, 30).utc,
            profile_verified_at: user.profiles.map(&:verified_at).max,
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
              requested_at: DateTime.new(2022, 8, 16).utc,
              returned_at: DateTime.new(2022, 10, 5).utc,
              profile_verified_at: user.profiles[0].verified_at,
              billable: true,
            )
          end
        end
      end

      it 'adds up new unique users from sp_return_log instances and splits based on profile age' do
        rows = [
          {
            partner: partner_key,
            issuers: issuers,
            year_month: '202009',
            iaa_start_date: partner_range.begin.to_s,
            iaa_end_date: partner_range.end.to_s,
            unique_user_proofed_events: 8,
            partner_ial2_unique_user_events_year1: 2,
            partner_ial2_unique_user_events_year2: 2,
            partner_ial2_unique_user_events_year3: 1,
            partner_ial2_unique_user_events_year4: 1,
            partner_ial2_unique_user_events_year5: 2,
            partner_ial2_unique_user_events_year_greater_than_5: 0,
            partner_ial2_unique_user_events_unknown: 0,
            new_unique_user_proofed_events: 8,
            partner_ial2_new_unique_user_events_year1: 2,
            partner_ial2_new_unique_user_events_year2: 2,
            partner_ial2_new_unique_user_events_year3: 1,
            partner_ial2_new_unique_user_events_year4: 1,
            partner_ial2_new_unique_user_events_year5: 2,
            partner_ial2_new_unique_user_events_year_greater_than_5: 0,
            partner_ial2_new_unique_user_events_unknown: 0,
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
            partner_ial2_new_unique_user_events_year1: 3,
            partner_ial2_new_unique_user_events_year2: 2,
            partner_ial2_new_unique_user_events_year3: 0,
            partner_ial2_new_unique_user_events_year4: 0,
            partner_ial2_new_unique_user_events_year5: 0,
            partner_ial2_new_unique_user_events_year_greater_than_5: 2,
            partner_ial2_new_unique_user_events_unknown: 1,
          },
        ]
        expect(results).to match_array(rows)
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
  end
end
