require 'rails_helper'
RSpec.configure do |rspec|
  rspec.expect_with :rspec do |c|
    c.max_formatted_output_length = nil
  end
end

RSpec.describe Db::MonthlySpAuthCount::UniqueMonthlyAuthCountsByPartner do
  describe '.call' do
    let(:key) { 'DHS' }
    let(:partner_account) do
      {
        key: key,
        start_date: 1.year.ago,
        end_date: Time.zone.now,
        issuers: [],
      }
    end
    let(:service_provider) { create(:service_provider) }

    subject(:results) do
      Db::MonthlySpAuthCount::UniqueMonthlyAuthCountsByPartner.call(**partner_account)
    end

    it 'is empty with no data issuers' do
      expect(results).to eq([])
    end

    context 'with data' do
      let(:key1) { 'DHS' }
      let(:key2) { 'VA' }
      let(:partner_account1) do
        {
          key: key1,
          start_date: partner_range.begin,
          end_date: partner_range.end,
          issuers: [issuer1, issuer2, issuer3],
        }
      end
      let(:partner_account2) do
        {
          key: key2,
          start_date: partner_range.begin,
          end_date: partner_range.end,
          issuers: [issuer4, issuer5],
        }
      end
      let(:partner_range) { Date.new(2020, 9, 15)..Date.new(2021, 9, 14) }
      let(:inside_partial_month) { Date.new(2020, 9, 16) }
      let(:inside_whole_month) { Date.new(2020, 10, 16) }

      let(:user1) { create(:user, profiles: [profile1]) }
      let(:profile1) { create(:profile, verified_at: '2020-02-15') }

      let(:user2) { create(:user, profiles: [profile2]) }
      let(:profile2) { create(:profile, verified_at: '2016-12-25') }

      let(:user3) { create(:user, profiles: [profile3]) }
      let(:profile3) { create(:profile, verified_at: '2019-11-10') }

      let(:user4) { create(:user, profiles: [profile4]) }
      let(:profile4) { create(:profile, verified_at: '2018-03-01') }

      let(:user5) { create(:user, profiles: [profile5]) }
      let(:profile5) { create(:profile, verified_at: '2019-09-17') }

      let(:user6) { create(:user, profiles: [profile6]) }
      let(:profile6) { create(:profile, verified_at: '2017-08-01') }

      let(:user7) { create(:user, profiles: [profile7]) }
      let(:profile7) { create(:profile, verified_at: '2016-09-15') }

      let(:user8) { create(:user, profiles: [profile8]) }
      let(:profile8) { create(:profile, verified_at: '2012-11-20') }

      let(:user9) { create(:user, profiles: [profile9]) }
      let(:profile9) { create(:profile, verified_at: '2022-12-15') }

      let(:user10) { create(:user, profiles: [profile10]) }
      let(:profile10) { create(:profile, verified_at: nil) }

      let(:issuer1) { 'issuer1' }
      let(:issuer2) { 'issuer2' }
      let(:issuer3) { 'issuer3' }
      let(:issuer4) { 'issuer4' }
      let(:issuer5) { 'issuer5' }

      let!(:sps) do
        [issuer1, issuer2, issuer3].map do |issuer|
          create(
            :service_provider,
            iaa: partner_account,
            issuer: issuer,
            iaa_start_date: partner_range.begin,
            iaa_end_date: partner_range.end,
          )
        end
      end

      before do
        # non-billable event in partial month, should be ignored
        binding.pry
        create(
          :sp_return_log,
          user_id: user1.id,
          issuer: issuer1,
          ial: 2,
          requested_at: inside_partial_month,
          returned_at: inside_partial_month,
          profile_verified_at: user1.profiles[0].verified_at,
          billable: false,
        )

        # 2 unique user in partial month each with different partners
        # [user1, user2].each do |user|
        #   create(
        #     :sp_return_log,
        #     user_id: user.id,
        #     issuer: issuer2,
        #     ial: 2,
        #     returned_at: inside_partial_month,
        #     profile_verified_at: user.profiles[0].verified_at,
        #     billable: true,
        #   )
        # end

        # # 2 old user (different partner) + 1 new user @ partner1 in whole month
        # [user1, user2, user3].each do |user|
        #   2.times do
        #     create(
        #       :sp_return_log,
        #       user_id: user.id,
        #       ial: 2,
        #       issuer: issuer2,
        #       returned_at: inside_whole_month,
        #       profile_verified_at: user.profiles[0].verified_at,
        #       billable: true,
        #     )
        #   end
        # end

        # #  5 new users in partial month proofed in year 1-5 @ partner2
        #   [user 1].each do |user|
        #     3.times do
        #       create(
        #         :sp_return_log,
        #         user_id: user.id,
        #         ial: 2,
        #         issuer: issuer2,
        #         returned_at: inside_partial_month,
        #         profile_verified_at: user.profiles[0].verified_at,
        #         billable: true,
        #       )
        #     end
        #   end
        #   binding.pry

        #   # 2 new users nil profile verified and > 5 year bucket in whole month @ partner 1
        #   [user1, user2, user3].each do |user|
        #     3.times do
        #       create(
        #         :sp_return_log,
        #         user_id: user.id,
        #         ial: 2,
        #         issuer: issuer2,
        #         requested_at: "2020-08-16",
        #         returned_at: "2020-10-05",
        #         profile_verified_at: user.profiles[0].verified_at,
        #         billable: true,
        #       )
        #     end
        #   end

        #   # 1 old user returning with new profile age in whole month @ partner 1
        #   binding.pry
        #   [user4].each do |user, profile|
        #     3.times do
        #       create(
        #         :sp_return_log,
        #         user_id: user.id,
        #         ial: 2,
        #         issuer: issuer2,
        #         requested_at: "2020-08-16",
        #         returned_at: "2020-10-05",
        #         profile_verified_at: user.profiles[0].verified_at,
        #         billable: true,
        #       )
        #     end
        #   end

        #   # 1 old user with new profile (new requesting agency and profile verification) in whole month @ partner 1
        #   binding.pry
        #   [user4].each do |user, profile|
        #     3.times do
        #       create(
        #         :sp_return_log,
        #         user_id: user.id,
        #         ial: 2,
        #         issuer: issuer2,
        #         requested_at: "2020-08-16",
        #         returned_at: "2020-10-05",
        #         profile_verified_at: user.profiles[0].verified_at,
        #         billable: true,
        #       )
        #     end
        #   end

        #   # 1 new user returning outside the range of analysis @ partner 1
        #   binding.pry
        #   [user4].each do |user, profile|
        #     3.times do
        #       create(
        #         :sp_return_log,
        #         user_id: user.id,
        #         ial: 2,
        #         issuer: issuer2,
        #         requested_at: "2020-08-16",
        #         returned_at: "2020-10-05",
        #         profile_verified_at: user.profiles[0].verified_at,
        #         billable: true,
        #       )
        #     end
        #   end
      end

      it 'adds up new unique users from sp_return_log instances and splits based on profile age' do
        rows = [
          {
            key: key1,
            year_month: '202009',
            iaa_start_date: partner_range.begin.to_s,
            iaa_end_date: partner_range.end.to_s,
            unique_users: 0,
            new_unique_users: 0,
            partner_ial2_new_unique_users_year1: 0,
            partner_ial2_new_unique_users_year2: 0,
            partner_ial2_new_unique_users_year3: 0,
            partner_ial2_new_unique_users_year4: 0,
            partner_ial2_new_unique_users_year5: 0,
            partner_ial2_new_unique_users_year_greater_than_5: 0,
            partner_ial2_new_unique_users_unknown: 0,
          },
          {
            key: key1,
            year_month: '202010',
            iaa_start_date: partner_range.begin.to_s,
            iaa_end_date: partner_range.end.to_s,
            unique_users: 0,
            new_unique_users: 0,
            partner_ial2_new_unique_users_year1: 0,
            partner_ial2_new_unique_users_year2: 0,
            partner_ial2_new_unique_users_year3: 0,
            partner_ial2_new_unique_users_year4: 0,
            partner_ial2_new_unique_users_year5: 0,
            partner_ial2_new_unique_users_year_greater_than_5: 0,
            partner_ial2_new_unique_users_unknown: 0,
          },
          {
            key: key2,
            year_month: '202009',
            iaa_start_date: partner_range.begin.to_s,
            iaa_end_date: partner_range.end.to_s,
            unique_users: 0,
            new_unique_users: 0,
            partner_ial2_new_unique_users_year1: 0,
            partner_ial2_new_unique_users_year2: 0,
            partner_ial2_new_unique_users_year3: 0,
            partner_ial2_new_unique_users_year4: 0,
            partner_ial2_new_unique_users_year5: 0,
            partner_ial2_new_unique_users_year_greater_than_5: 0,
            partner_ial2_new_unique_users_unknown: 0,
          },
          {
            key: key2,
            year_month: '202010',
            iaa_start_date: partner_range.begin.to_s,
            iaa_end_date: partner_range.end.to_s,
            unique_users: 0,
            new_unique_users: 0,
            partner_ial2_new_unique_users_year1: 0,
            partner_ial2_new_unique_users_year2: 0,
            partner_ial2_new_unique_users_year3: 0,
            partner_ial2_new_unique_users_year4: 0,
            partner_ial2_new_unique_users_year5: 0,
            partner_ial2_new_unique_users_year_greater_than_5: 0,
            partner_ial2_new_unique_users_unknown: 0,
          },
        ]
        # binding.pry
        expect(results).to match_array(rows)
        # binding.pry
      end
    end

    context 'with only partial month data' do
      let(:partner_range) { Date.new(2020, 9, 15)..Date.new(2020, 9, 17) }
      let(:issuer) { 'issuer1' }
      let(:rows) { [] }

      it 'adds up auth_counts and sp_return_log instances' do
        expect(results).to match_array(rows)
      end
    end
  end
end

# Test cases for ial2 proofing each year (different sums)
# test case to capture reproofing > 5 years
# create users outside of the range for testing to make sure our build query functions within the range only
