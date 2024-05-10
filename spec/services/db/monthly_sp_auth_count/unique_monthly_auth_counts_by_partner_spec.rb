require 'rails_helper'
RSpec.configure do |rspec|
  rspec.expect_with :rspec do |c|
    c.max_formatted_output_length = nil
  end
end

RSpec.describe Db::MonthlySpAuthCount::UniqueMonthlyAuthCountsByPartner do
  describe '.call' do
    subject(:results) do
      Db::MonthlySpAuthCount::UniqueMonthlyAuthCountsByPartner.call(
        key: key,
        start_date: partner_range.begin,
        end_date: partner_range.end,
        issuers: issuers,
      )
    end

    context 'with no data' do
      let(:key) { partner }
      let(:partner) { 'DHS' }
      let(:partner_range) {1.year.ago..Time.zone.now }
      let(:issuers) { [] }

      it 'is empty with no data issuers' do
        expect(results).to eq([])
      end
    end

    context 'with data' do
      let(:key) { 'DHS' }
      let(:issuers) { [issuer1, issuer2, issuer3] }

      let(:partner_range) { Date.new(2020, 9, 15)..Date.new(2021, 9, 14) }
      let(:inside_partial_month) { Date.new(2020, 9, 16) }
      let(:inside_whole_month) { Date.new(2020, 10, 16) }

      let(:user1) { create(:user, profiles: [profile1a, profile1b]) }
      let(:profile1a) { create(:profile, verified_at: '2015-09-16') }
      let(:profile1b) { create(:profile, verified_at: '2020-09-16') }

      let(:user2) { create(:user, profiles: [profile2]) }
      let(:profile2) { create(:profile, verified_at: '2018-12-25') }

      let(:user3) { create(:user, profiles: [profile3]) }
      let(:profile3) { create(:profile, verified_at: '2019-11-10') }

      let(:user4) { create(:user, profiles: [profile4]) }
      let(:profile4) { create(:profile, verified_at: '2020-03-01') }

      let(:user5) { create(:user, profiles: [profile5]) }
      let(:profile5) { create(:profile, verified_at: '2019-04-17') }

      let(:user6) { create(:user, profiles: [profile6]) }
      let(:profile6) { create(:profile, verified_at: '2018-09-15') }

      let(:user7) { create(:user, profiles: [profile7]) }
      let(:profile7) { create(:profile, verified_at: '2017-02-15') }

      let(:user8) { create(:user, profiles: [profile8]) }
      let(:profile8) { create(:profile, verified_at: '2016-03-20') }

      let(:user9) { create(:user, profiles: [profile9]) }
      let(:profile9) { create(:profile, verified_at: '2012-12-15') }

      let(:user10) { create(:user, profiles: [profile10]) }
      let(:profile10) { create(:profile, verified_at: nil) }

      let(:user11) { create(:user, profiles: [profile9]) }
      let(:profile11) { create(:profile, verified_at: '2019-11-10') }

      let(:issuer1) { 'issuer1' }
      let(:issuer2) { 'issuer2' }
      let(:issuer3) { 'issuer3' }

      before do
        # non-billable event in partial month, should be ignored
        # binding.pry
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
            profile_verified_at: user.profiles.map(&:verified_at).max,
            billable: true,
          )
        end

        # 2 old user + 1 new user in whole month
        [user1, user2, user3].each do |user|
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

        # #  5 new users in whole month proofed in year 1-5
        [user4, user5, user6, user7, user8].each do |user|
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

        # 1 new user returning outside the range of analysis 
        [user11].each do |user, profile|
          3.times do
            create(
              :sp_return_log,
              user_id: user.id,
              ial: 2,
              issuer: issuer2,
              requested_at: '2021-08-16',
              returned_at: '2021-10-05',
              profile_verified_at: user.profiles[0].verified_at,
              billable: true,
            )
          end
        end
      end

      it 'adds up new unique users from sp_return_log instances and splits based on profile age' do
        rows = [
          {
            key: key,
            year_month: '202009',
            iaa_start_date: partner_range.begin.to_s,
            iaa_end_date: partner_range.end.to_s,
            unique_users: 7,
            new_unique_users: 7,
            partner_ial2_new_unique_users_year1: 2,
            partner_ial2_new_unique_users_year2: 2,
            partner_ial2_new_unique_users_year3: 1,
            partner_ial2_new_unique_users_year4: 1,
            partner_ial2_new_unique_users_year5: 1,
            partner_ial2_new_unique_users_year_greater_than_5: 0,
            partner_ial2_new_unique_users_unknown: 0,
          },
          {
            key: key,
            year_month: '202010',
            iaa_start_date: partner_range.begin.to_s,
            iaa_end_date: partner_range.end.to_s,
            unique_users: 6,
            new_unique_users: 3,
            partner_ial2_new_unique_users_year1: 1,
            partner_ial2_new_unique_users_year2: 0,
            partner_ial2_new_unique_users_year3: 0,
            partner_ial2_new_unique_users_year4: 0,
            partner_ial2_new_unique_users_year5: 0,
            partner_ial2_new_unique_users_year_greater_than_5: 1,
            partner_ial2_new_unique_users_unknown: 1,
          },
        ]

        expect(results).to match_array(rows)

      end
    end

    context 'with only partial month data' do
      let(:key) { 'DHS' }
      let(:partner_range) { Date.new(2020, 9, 15)..Date.new(2020, 9, 17) }
      let(:issuers) { ['issuer1'] }
      let(:rows) { [] }

      it 'adds up auth_counts and sp_return_log instances' do
        expect(results).to match_array(rows)
      end
    end
  end
end
