require 'rails_helper'

RSpec.describe Reports::CombinedInvoiceSupplementReportV2 do
  subject(:report) { Reports::CombinedInvoiceSupplementReportV2.new }

  before do
    clear_agreements_data
    ServiceProvider.delete_all
  end

  describe '#perform' do
    it 'is empty with no data' do
      csv = CSV.parse(report.perform(Time.zone.today), headers: true)
      expect(csv).to be_empty
    end

    context 'with data generates reports by iaa + order number, issuer and year_month' do
      context 'with an IAA with a single issuer in April 2020' do
        let(:partner_account1) { create(:partner_account) }
        let(:iaa1_range) { DateTime.new(2020, 4, 15).utc..DateTime.new(2021, 4, 14).utc }

        let(:gtc1) do
          create(
            :iaa_gtc,
            gtc_number: 'gtc1234',
            partner_account: partner_account1,
            start_date: iaa1_range.begin,
            end_date: iaa1_range.end,
          )
        end

        let(:iaa1) { 'iaa1' }

        let(:iaa1_sp) do
          create(
            :service_provider,
            iaa: iaa1,
            iaa_start_date: iaa1_range.begin,
            iaa_end_date: iaa1_range.end,
          )
        end

        let(:iaa_order1) do
          build_iaa_order(order_number: 1, date_range: iaa1_range, iaa_gtc: gtc1)
        end

        let(:inside_iaa1) { iaa1_range.begin + 1.day }

        let(:user1) { create(:user, profiles: [profile1]) }
        let(:profile1) { build(:profile, verified_at: DateTime.new(2018, 6, 1).utc) }

        let(:user2) { create(:user, profiles: [profile2]) }
        let(:profile2) { build(:profile, verified_at: DateTime.new(2018, 6, 1).utc) }
        let(:report_date) { inside_iaa1 }

        let(:csv) do
          travel_to report_date do
            CSV.parse(report.perform(report_date), headers: true)
          end
        end

        before do
          iaa_order1.integrations << build_integration(
            issuer: iaa1_sp.issuer,
            partner_account: partner_account1,
          )
          iaa_order1.save

          # 1 new unique user in month 1 at IAA 1 sp @ IAL 1
          7.times do
            create_sp_return_log(
              user: user1,
              issuer: iaa1_sp.issuer,
              ial: 1,
              returned_at: inside_iaa1,
            )
          end

          # 2 new unique users in month 1 at IAA 1 sp @ IAL 2 with profile age 2
          # user1 is both IAL1 and IAL2
          [user1, user2].each do |user|
            create_sp_return_log(
              user: user,
              issuer: iaa1_sp.issuer,
              ial: 2,
              returned_at: inside_iaa1,
            )
          end
        end

        it 'checks authentication counts in ial1 + ial2 & checks partner single issuer cases' do
          expect(csv.length).to eq(1)
          aggregate_failures do
            row = csv.find { |r| r['issuer'] == iaa1_sp.issuer }
            expect(row['iaa_order_number']).to eq('gtc1234-0001')
            expect(row['partner']).to eq(partner_account1.requesting_agency)
            expect(row['iaa_start_date']).to eq('2020-04-15')
            expect(row['iaa_end_date']).to eq('2021-04-14')

            expect(row['issuer']).to eq(iaa1_sp.issuer)
            expect(row['friendly_name']).to eq(iaa1_sp.friendly_name)

            expect(row['year_month']).to eq('202004')
            expect(row['year_month_readable']).to eq('April 2020')

            expect(row['iaa_ial1_unique_users'].to_i).to eq(1)
            expect(row['iaa_ial2_unique_users'].to_i).to eq(2)
            expect(row['iaa_unique_users'].to_i).to eq(2)
            expect(row['partner_ial2_unique_user_events_year1'].to_i).to eq(0)
            expect(row['partner_ial2_unique_user_events_year2'].to_i).to eq(2)
            expect(row['partner_ial2_unique_user_events_year3'].to_i).to eq(0)
            expect(row['partner_ial2_unique_user_events_year4'].to_i).to eq(0)
            expect(row['partner_ial2_unique_user_events_year5'].to_i).to eq(0)
            expect(row['partner_ial2_unique_user_events_year_greater_than_5'].to_i).to eq(0)
            expect(row['partner_ial2_unique_user_events_unknown'].to_i).to eq(0)
            expect(row['partner_ial2_new_unique_user_events_year1'].to_i).to eq(0)
            expect(row['partner_ial2_new_unique_user_events_year2'].to_i).to eq(2)
            expect(row['partner_ial2_new_unique_user_events_year3'].to_i).to eq(0)
            expect(row['partner_ial2_new_unique_user_events_year4'].to_i).to eq(0)
            expect(row['partner_ial2_new_unique_user_events_year5'].to_i).to eq(0)
            expect(row['partner_ial2_new_unique_user_events_year_greater_than_5'].to_i).to eq(0)
            expect(row['partner_ial2_new_unique_user_events_unknown'].to_i).to eq(0)

            expect(row['issuer_ial2_unique_user_events_year1'].to_i).to eq(0)
            expect(row['issuer_ial2_unique_user_events_year2'].to_i).to eq(2)
            expect(row['issuer_ial2_unique_user_events_year3'].to_i).to eq(0)
            expect(row['issuer_ial2_unique_user_events_year4'].to_i).to eq(0)
            expect(row['issuer_ial2_unique_user_events_year5'].to_i).to eq(0)
            expect(row['issuer_ial2_unique_user_events_year_greater_than_5'].to_i).to eq(0)
            expect(row['issuer_ial2_unique_user_events_unknown'].to_i).to eq(0)
            expect(row['issuer_ial2_new_unique_user_events_year1'].to_i).to eq(0)
            expect(row['issuer_ial2_new_unique_user_events_year2'].to_i).to eq(2)
            expect(row['issuer_ial2_new_unique_user_events_year3'].to_i).to eq(0)
            expect(row['issuer_ial2_new_unique_user_events_year4'].to_i).to eq(0)
            expect(row['issuer_ial2_new_unique_user_events_year5'].to_i).to eq(0)
            expect(row['issuer_ial2_new_unique_user_events_year_greater_than_5'].to_i).to eq(0)
            expect(row['issuer_ial2_new_unique_user_events_unknown'].to_i).to eq(0)

            expect(row['issuer_ial1_total_auth_count'].to_i).to eq(7)
            expect(row['issuer_ial2_total_auth_count'].to_i).to eq(2)
            expect(row['issuer_ial1_plus_2_total_auth_count'].to_i).to eq(9)

            expect(row['issuer_ial1_unique_users'].to_i).to eq(1)
            expect(row['issuer_ial2_unique_users'].to_i).to eq(2)
            expect(row['issuer_unique_users'].to_i).to eq(2)
          end
        end

        context 'when IAA ended more than 90 days ago' do
          let(:report_date) { iaa1_range.end + 90.days }

          it 'is excluded from the report' do
            expect(csv.length).to eq(0)
          end
        end
      end

      context 'with an IAA with two issuers in September 2020' do
        let(:partner_account2) { create(:partner_account) }
        let(:iaa2_range) { DateTime.new(2020, 9, 1).utc..DateTime.new(2021, 8, 30).utc }

        let(:gtc2) do
          create(
            :iaa_gtc,
            gtc_number: 'gtc5678',
            partner_account: partner_account2,
            start_date: iaa2_range.begin,
            end_date: iaa2_range.end,
          )
        end

        let(:iaa2) { 'iaa2' }

        let(:iaa2_sp1) do
          create(
            :service_provider,
            iaa: iaa2,
            iaa_start_date: iaa2_range.begin,
            iaa_end_date: iaa2_range.end,
          )
        end

        let(:iaa2_sp2) do
          create(
            :service_provider,
            iaa: iaa2,
            iaa_start_date: iaa2_range.begin,
            iaa_end_date: iaa2_range.end,
          )
        end

        let(:iaa_order2) do
          build_iaa_order(order_number: 2, date_range: iaa2_range, iaa_gtc: gtc2)
        end

        let(:inside_iaa2) { iaa2_range.begin + 1.day }

        let(:user1) { create(:user, profiles: [profile1]) }
        let(:profile1) { build(:profile, verified_at: DateTime.new(2019, 10, 15).utc) }

        let(:user4) { create(:user, profiles: [profile4]) }
        let(:profile4) { build(:profile, verified_at: nil) }

        let(:user5) { create(:user, profiles: [profile5]) }
        let(:profile5) { build(:profile, verified_at: DateTime.new(2019, 1, 1).utc) }

        let(:user6) { create(:user, profiles: [profile6]) }
        let(:profile6) { build(:profile, verified_at: DateTime.new(2019, 1, 1).utc) }

        let(:user7) { create(:user, profiles: [profile7]) }
        let(:profile7) { build(:profile, verified_at: DateTime.new(2018, 1, 1).utc) }

        let(:user8) { create(:user, profiles: [profile8]) }
        let(:profile8) { build(:profile, verified_at: DateTime.new(2017, 1, 1).utc) }

        let(:user9) { create(:user, profiles: [profile9]) }
        let(:profile9) { build(:profile, verified_at: DateTime.new(2016, 1, 1).utc) }

        let(:user10) { create(:user, profiles: [profile10]) }
        let(:profile10) { build(:profile, verified_at: DateTime.new(2015, 1, 1).utc) }

        let(:csv) do
          travel_to inside_iaa2 do
            CSV.parse(report.perform(Time.zone.today), headers: true)
          end
        end

        before do
          iaa_order2.integrations << build_integration(
            issuer: iaa2_sp1.issuer,
            partner_account: partner_account2,
          )
          iaa_order2.integrations << build_integration(
            issuer: iaa2_sp2.issuer,
            partner_account: partner_account2,
          )
          iaa_order2.save

          # ----- iaa2_sp1 sp_return_logs -----
          # 1 new unique user in month 1 at IAA 2 sp 1 @ IAL 2 with profile age 1
          create_sp_return_log(
            user: user1, issuer: iaa2_sp1.issuer, ial: 2,
            returned_at: inside_iaa2
          )

          # 1 new unique user in month 1 at IAA 2 sp 1 @ IAL 2 with profile age 3
          create_sp_return_log(
            user: user7, issuer: iaa2_sp1.issuer, ial: 2,
            returned_at: inside_iaa2
          )

          # 1 new unique user in month 1 at IAA 2 sp 1 @ IAL 2 with profile age 5
          create_sp_return_log(
            user: user9, issuer: iaa2_sp1.issuer, ial: 2,
            returned_at: inside_iaa2
          )

          # 1 new unique user in month 1 at IAA 2 sp 1 @ IAL 2 with profile age unknown
          create_sp_return_log(
            user: user4, issuer: iaa2_sp1.issuer, ial: 2,
            returned_at: inside_iaa2
          )

          # ----- iaa2_sp2 sp_return_logs -----
          # 2 new unique user in month 1 at IAA 2 sp 2 @ IAL 2 with profile age 2
          [user5, user6].each do |user|
            create_sp_return_log(
              user: user, issuer: iaa2_sp2.issuer, ial: 2,
              returned_at: inside_iaa2
            )
          end

          # 1 new unique user in month 1 at IAA 2 sp 2 @ IAL 2 with profile age 4
          create_sp_return_log(
            user: user8, issuer: iaa2_sp2.issuer, ial: 2,
            returned_at: inside_iaa2
          )

          # 1 new unique user in month 1 at IAA 2 sp 2 @ IAL 2 with profile age > 5
          create_sp_return_log(
            user: user10, issuer: iaa2_sp2.issuer, ial: 2,
            returned_at: inside_iaa2
          )
        end

        it 'checks values for all profile age columns and multiple issuers for single partner' do
          aggregate_failures do
            row = csv.find { |r| r['issuer'] == iaa2_sp1.issuer }

            expect(row['iaa_order_number']).to eq('gtc5678-0002')
            expect(row['partner']).to eq(partner_account2.requesting_agency)
            expect(row['iaa_start_date']).to eq('2020-09-01')
            expect(row['iaa_end_date']).to eq('2021-08-30')

            expect(row['issuer']).to eq(iaa2_sp1.issuer)
            expect(row['friendly_name']).to eq(iaa2_sp1.friendly_name)

            expect(row['year_month']).to eq('202009')
            expect(row['year_month_readable']).to eq('September 2020')

            expect(row['iaa_ial1_unique_users'].to_i).to eq(0)
            expect(row['iaa_ial2_unique_users'].to_i).to eq(8)
            expect(row['iaa_unique_users'].to_i).to eq(8)
            expect(row['partner_ial2_unique_user_events_year1'].to_i).to eq(1)
            expect(row['partner_ial2_unique_user_events_year2'].to_i).to eq(2)
            expect(row['partner_ial2_unique_user_events_year3'].to_i).to eq(1)
            expect(row['partner_ial2_unique_user_events_year4'].to_i).to eq(1)
            expect(row['partner_ial2_unique_user_events_year5'].to_i).to eq(1)
            expect(row['partner_ial2_unique_user_events_year_greater_than_5'].to_i).to eq(1)
            expect(row['partner_ial2_unique_user_events_unknown'].to_i).to eq(1)
            expect(row['partner_ial2_new_unique_user_events_year1'].to_i).to eq(1)
            expect(row['partner_ial2_new_unique_user_events_year2'].to_i).to eq(2)
            expect(row['partner_ial2_new_unique_user_events_year3'].to_i).to eq(1)
            expect(row['partner_ial2_new_unique_user_events_year4'].to_i).to eq(1)
            expect(row['partner_ial2_new_unique_user_events_year5'].to_i).to eq(1)
            expect(row['partner_ial2_new_unique_user_events_year_greater_than_5'].to_i).to eq(1)
            expect(row['partner_ial2_new_unique_user_events_unknown'].to_i).to eq(1)

            expect(row['issuer_ial2_unique_user_events_year1'].to_i).to eq(1)
            expect(row['issuer_ial2_unique_user_events_year2'].to_i).to eq(0)
            expect(row['issuer_ial2_unique_user_events_year3'].to_i).to eq(1)
            expect(row['issuer_ial2_unique_user_events_year4'].to_i).to eq(0)
            expect(row['issuer_ial2_unique_user_events_year5'].to_i).to eq(1)
            expect(row['issuer_ial2_unique_user_events_year_greater_than_5'].to_i).to eq(0)
            expect(row['issuer_ial2_unique_user_events_unknown'].to_i).to eq(1)
            expect(row['issuer_ial2_new_unique_user_events_year1'].to_i).to eq(1)
            expect(row['issuer_ial2_new_unique_user_events_year2'].to_i).to eq(0)
            expect(row['issuer_ial2_new_unique_user_events_year3'].to_i).to eq(1)
            expect(row['issuer_ial2_new_unique_user_events_year4'].to_i).to eq(0)
            expect(row['issuer_ial2_new_unique_user_events_year5'].to_i).to eq(1)
            expect(row['issuer_ial2_new_unique_user_events_year_greater_than_5'].to_i).to eq(0)
            expect(row['issuer_ial2_new_unique_user_events_unknown'].to_i).to eq(1)

            expect(row['issuer_ial1_total_auth_count'].to_i).to eq(0)
            expect(row['issuer_ial2_total_auth_count'].to_i).to eq(4)
            expect(row['issuer_ial1_plus_2_total_auth_count'].to_i).to eq(4)

            expect(row['issuer_ial1_unique_users'].to_i).to eq(0)
            expect(row['issuer_ial2_unique_users'].to_i).to eq(4)
            expect(row['issuer_unique_users'].to_i).to eq(4)
          end

          aggregate_failures do
            row = csv.find { |r| r['issuer'] == iaa2_sp2.issuer }

            expect(row['iaa_order_number']).to eq('gtc5678-0002')
            expect(row['partner']).to eq(partner_account2.requesting_agency)
            expect(row['iaa_start_date']).to eq('2020-09-01')
            expect(row['iaa_end_date']).to eq('2021-08-30')

            expect(row['issuer']).to eq(iaa2_sp2.issuer)
            expect(row['friendly_name']).to eq(iaa2_sp2.friendly_name)

            expect(row['year_month']).to eq('202009')
            expect(row['year_month_readable']).to eq('September 2020')

            expect(row['iaa_ial1_unique_users'].to_i).to eq(0)
            expect(row['iaa_ial2_unique_users'].to_i).to eq(8)
            expect(row['iaa_unique_users'].to_i).to eq(8)
            expect(row['partner_ial2_unique_user_events_year1'].to_i).to eq(1)
            expect(row['partner_ial2_unique_user_events_year2'].to_i).to eq(2)
            expect(row['partner_ial2_unique_user_events_year3'].to_i).to eq(1)
            expect(row['partner_ial2_unique_user_events_year4'].to_i).to eq(1)
            expect(row['partner_ial2_unique_user_events_year5'].to_i).to eq(1)
            expect(row['partner_ial2_unique_user_events_year_greater_than_5'].to_i).to eq(1)
            expect(row['partner_ial2_unique_user_events_unknown'].to_i).to eq(1)
            expect(row['partner_ial2_new_unique_user_events_year1'].to_i).to eq(1)
            expect(row['partner_ial2_new_unique_user_events_year2'].to_i).to eq(2)
            expect(row['partner_ial2_new_unique_user_events_year3'].to_i).to eq(1)
            expect(row['partner_ial2_new_unique_user_events_year4'].to_i).to eq(1)
            expect(row['partner_ial2_new_unique_user_events_year5'].to_i).to eq(1)
            expect(row['partner_ial2_new_unique_user_events_year_greater_than_5'].to_i).to eq(1)
            expect(row['partner_ial2_new_unique_user_events_unknown'].to_i).to eq(1)

            expect(row['issuer_ial2_unique_user_events_year1'].to_i).to eq(0)
            expect(row['issuer_ial2_unique_user_events_year2'].to_i).to eq(2)
            expect(row['issuer_ial2_unique_user_events_year3'].to_i).to eq(0)
            expect(row['issuer_ial2_unique_user_events_year4'].to_i).to eq(1)
            expect(row['issuer_ial2_unique_user_events_year5'].to_i).to eq(0)
            expect(row['issuer_ial2_unique_user_events_year_greater_than_5'].to_i).to eq(1)
            expect(row['issuer_ial2_unique_user_events_unknown'].to_i).to eq(0)
            expect(row['issuer_ial2_new_unique_user_events_year1'].to_i).to eq(0)
            expect(row['issuer_ial2_new_unique_user_events_year2'].to_i).to eq(2)
            expect(row['issuer_ial2_new_unique_user_events_year3'].to_i).to eq(0)
            expect(row['issuer_ial2_new_unique_user_events_year4'].to_i).to eq(1)
            expect(row['issuer_ial2_new_unique_user_events_year5'].to_i).to eq(0)
            expect(row['issuer_ial2_new_unique_user_events_year_greater_than_5'].to_i).to eq(1)
            expect(row['issuer_ial2_new_unique_user_events_unknown'].to_i).to eq(0)

            expect(row['issuer_ial1_total_auth_count'].to_i).to eq(0)
            expect(row['issuer_ial2_total_auth_count'].to_i).to eq(4)
            expect(row['issuer_ial1_plus_2_total_auth_count'].to_i).to eq(4)

            expect(row['issuer_ial1_unique_users'].to_i).to eq(0)
            expect(row['issuer_ial2_unique_users'].to_i).to eq(4)
            expect(row['issuer_unique_users'].to_i).to eq(4)
          end
        end
      end

      context 'with an IAA with a single issuer in from September-October 2020' do
        let(:partner_account3) { create(:partner_account) }

        let(:iaa3_range) { DateTime.new(2020, 9, 1).utc..DateTime.new(2021, 8, 30).utc }
        let(:inside_iaa3) { iaa3_range.begin + 1.day }

        let(:gtc3) do
          create(
            :iaa_gtc,
            gtc_number: 'gtc9101',
            partner_account: partner_account3,
            start_date: iaa3_range.begin,
            end_date: iaa3_range.end,
          )
        end

        let(:iaa3) { 'iaa3' }

        let(:iaa3_sp1) do
          create(
            :service_provider,
            iaa: iaa3,
            iaa_start_date: iaa3_range.begin,
            iaa_end_date: iaa3_range.end,
          )
        end

        let(:iaa_order3) do
          build_iaa_order(order_number: 3, date_range: iaa3_range, iaa_gtc: gtc3)
        end

        let(:user11) { create(:user, profiles: [profile11]) }
        let(:profile11) { build(:profile, verified_at: DateTime.new(2019, 10, 10).utc) }

        let(:user12) { create(:user, profiles: [profile12]) }
        let(:profile12) { build(:profile, verified_at: DateTime.new(2017, 9, 10).utc) }

        let(:csv) do
          travel_to inside_iaa3 do
            CSV.parse(report.perform(Time.zone.today), headers: true)
          end
        end

        before do
          iaa_order3.integrations << build_integration(
            issuer: iaa3_sp1.issuer,
            partner_account: partner_account3,
          )
          iaa_order3.save

          # 1 new unique user in month 1 at IAA 3 sp 1 @ IAL 2 with profile age 1
          create_sp_return_log(
            user: user11, issuer: iaa3_sp1.issuer, ial: 2,
            returned_at: iaa3_range.begin + 2.days
          )

          # 1 old unique user in month 2 at IAA 3 sp 1 @ IAL 2 with profile age 1 + 2 in month 2
          create_sp_return_log(
            user: user11, issuer: iaa3_sp1.issuer, ial: 2,
            returned_at: DateTime.new(2020, 10, 2).utc
          )
          create_sp_return_log(
            user: user11, issuer: iaa3_sp1.issuer, ial: 2,
            returned_at: DateTime.new(2020, 10, 20).utc
          )

          # 1 new unique user in month 1 at IAA 3 sp 1 @ IAL 2
          # reproof event in same month profile age 3 -> 1
          create_sp_return_log(
            user: user12, issuer: iaa3_sp1.issuer, ial: 2,
            returned_at: DateTime.new(2020, 10, 2).utc
          )

          create(
            :sp_return_log,
            user_id: user12.id,
            issuer: iaa3_sp1.issuer,
            ial: 2,
            requested_at: DateTime.new(2020, 10, 2),
            returned_at: DateTime.new(2020, 10, 20),
            profile_verified_at: DateTime.new(2020, 10, 20),
            billable: true,
          )
        end

        it 'checks for user reproof or change profile age events in same and different months' do
          aggregate_failures do
            row = csv.find { |r| r['issuer'] == iaa3_sp1.issuer && r['year_month'] == '202009' }

            expect(row['iaa_order_number']).to eq('gtc9101-0003')
            expect(row['partner']).to eq(partner_account3.requesting_agency)
            expect(row['iaa_start_date']).to eq('2020-09-01')
            expect(row['iaa_end_date']).to eq('2021-08-30')

            expect(row['issuer']).to eq(iaa3_sp1.issuer)
            expect(row['friendly_name']).to eq(iaa3_sp1.friendly_name)

            expect(row['year_month']).to eq('202009')
            expect(row['year_month_readable']).to eq('September 2020')

            expect(row['iaa_ial1_unique_users'].to_i).to eq(0)
            expect(row['iaa_ial2_unique_users'].to_i).to eq(1)
            expect(row['iaa_unique_users'].to_i).to eq(1)
            expect(row['partner_ial2_unique_user_events_year1'].to_i).to eq(1)
            expect(row['partner_ial2_unique_user_events_year2'].to_i).to eq(0)
            expect(row['partner_ial2_unique_user_events_year3'].to_i).to eq(0)
            expect(row['partner_ial2_unique_user_events_year4'].to_i).to eq(0)
            expect(row['partner_ial2_unique_user_events_year5'].to_i).to eq(0)
            expect(row['partner_ial2_unique_user_events_year_greater_than_5'].to_i).to eq(0)
            expect(row['partner_ial2_unique_user_events_unknown'].to_i).to eq(0)
            expect(row['partner_ial2_new_unique_user_events_year1'].to_i).to eq(1)
            expect(row['partner_ial2_new_unique_user_events_year2'].to_i).to eq(0)
            expect(row['partner_ial2_new_unique_user_events_year3'].to_i).to eq(0)
            expect(row['partner_ial2_new_unique_user_events_year4'].to_i).to eq(0)
            expect(row['partner_ial2_new_unique_user_events_year5'].to_i).to eq(0)
            expect(row['partner_ial2_new_unique_user_events_year_greater_than_5'].to_i).to eq(0)
            expect(row['partner_ial2_new_unique_user_events_unknown'].to_i).to eq(0)

            expect(row['issuer_ial2_unique_user_events_year1'].to_i).to eq(1)
            expect(row['issuer_ial2_unique_user_events_year2'].to_i).to eq(0)
            expect(row['issuer_ial2_unique_user_events_year3'].to_i).to eq(0)
            expect(row['issuer_ial2_unique_user_events_year4'].to_i).to eq(0)
            expect(row['issuer_ial2_unique_user_events_year5'].to_i).to eq(0)
            expect(row['issuer_ial2_unique_user_events_year_greater_than_5'].to_i).to eq(0)
            expect(row['issuer_ial2_unique_user_events_unknown'].to_i).to eq(0)
            expect(row['issuer_ial2_new_unique_user_events_year1'].to_i).to eq(1)
            expect(row['issuer_ial2_new_unique_user_events_year2'].to_i).to eq(0)
            expect(row['issuer_ial2_new_unique_user_events_year3'].to_i).to eq(0)
            expect(row['issuer_ial2_new_unique_user_events_year4'].to_i).to eq(0)
            expect(row['issuer_ial2_new_unique_user_events_year5'].to_i).to eq(0)
            expect(row['issuer_ial2_new_unique_user_events_year_greater_than_5'].to_i).to eq(0)
            expect(row['issuer_ial2_new_unique_user_events_unknown'].to_i).to eq(0)

            expect(row['issuer_ial1_total_auth_count'].to_i).to eq(0)
            expect(row['issuer_ial2_total_auth_count'].to_i).to eq(1)
            expect(row['issuer_ial1_plus_2_total_auth_count'].to_i).to eq(1)

            expect(row['issuer_ial1_unique_users'].to_i).to eq(0)
            expect(row['issuer_ial2_unique_users'].to_i).to eq(1)
            expect(row['issuer_unique_users'].to_i).to eq(1)
          end

          aggregate_failures do
            row = csv.find { |r| r['issuer'] == iaa3_sp1.issuer && r['year_month'] == '202010' }

            expect(row['iaa_order_number']).to eq('gtc9101-0003')
            expect(row['partner']).to eq(partner_account3.requesting_agency)
            expect(row['iaa_start_date']).to eq(iaa3_sp1.iaa_start_date.to_s)
            expect(row['iaa_end_date']).to eq(iaa3_sp1.iaa_end_date.to_s)

            expect(row['issuer']).to eq(iaa3_sp1.issuer)
            expect(row['friendly_name']).to eq(iaa3_sp1.friendly_name)

            expect(row['year_month']).to eq('202010')
            expect(row['year_month_readable']).to eq('October 2020')

            expect(row['iaa_ial1_unique_users'].to_i).to eq(0)
            expect(row['iaa_ial2_unique_users'].to_i).to eq(2)
            expect(row['iaa_unique_users'].to_i).to eq(2)
            expect(row['partner_ial2_unique_user_events_year1'].to_i).to eq(2)
            expect(row['partner_ial2_unique_user_events_year2'].to_i).to eq(1)
            expect(row['partner_ial2_unique_user_events_year3'].to_i).to eq(0)
            expect(row['partner_ial2_unique_user_events_year4'].to_i).to eq(1)
            expect(row['partner_ial2_unique_user_events_year5'].to_i).to eq(0)
            expect(row['partner_ial2_unique_user_events_year_greater_than_5'].to_i).to eq(0)
            expect(row['partner_ial2_unique_user_events_unknown'].to_i).to eq(0)
            expect(row['partner_ial2_new_unique_user_events_year1'].to_i).to eq(1)
            expect(row['partner_ial2_new_unique_user_events_year2'].to_i).to eq(1)
            expect(row['partner_ial2_new_unique_user_events_year3'].to_i).to eq(0)
            expect(row['partner_ial2_new_unique_user_events_year4'].to_i).to eq(1)
            expect(row['partner_ial2_new_unique_user_events_year5'].to_i).to eq(0)
            expect(row['partner_ial2_new_unique_user_events_year_greater_than_5'].to_i).to eq(0)
            expect(row['partner_ial2_new_unique_user_events_unknown'].to_i).to eq(0)

            expect(row['issuer_ial2_unique_user_events_year1'].to_i).to eq(2)
            expect(row['issuer_ial2_unique_user_events_year2'].to_i).to eq(1)
            expect(row['issuer_ial2_unique_user_events_year3'].to_i).to eq(0)
            expect(row['issuer_ial2_unique_user_events_year4'].to_i).to eq(1)
            expect(row['issuer_ial2_unique_user_events_year5'].to_i).to eq(0)
            expect(row['issuer_ial2_unique_user_events_year_greater_than_5'].to_i).to eq(0)
            expect(row['issuer_ial2_unique_user_events_unknown'].to_i).to eq(0)
            expect(row['issuer_ial2_new_unique_user_events_year1'].to_i).to eq(1)
            expect(row['issuer_ial2_new_unique_user_events_year2'].to_i).to eq(1)
            expect(row['issuer_ial2_new_unique_user_events_year3'].to_i).to eq(0)
            expect(row['issuer_ial2_new_unique_user_events_year4'].to_i).to eq(1)
            expect(row['issuer_ial2_new_unique_user_events_year5'].to_i).to eq(0)
            expect(row['issuer_ial2_new_unique_user_events_year_greater_than_5'].to_i).to eq(0)
            expect(row['issuer_ial2_new_unique_user_events_unknown'].to_i).to eq(0)

            expect(row['issuer_ial1_total_auth_count'].to_i).to eq(0)
            expect(row['issuer_ial2_total_auth_count'].to_i).to eq(4)
            expect(row['issuer_ial1_plus_2_total_auth_count'].to_i).to eq(4)

            expect(row['issuer_ial1_unique_users'].to_i).to eq(0)
            expect(row['issuer_ial2_unique_users'].to_i).to eq(2)
            expect(row['issuer_unique_users'].to_i).to eq(2)
          end
        end
      end
    end
  end

  describe '#combine_by_iaa_month' do
    let(:service_provider) { create(:service_provider) }

    let(:by_iaa_results) do
      [
        {
          key: 'IAA123',
          year_month: '202408',
          iaa_start_date: '2024-08-01',
          iaa_end_date: '2025-07-31',
        },
      ]
    end

    let(:by_issuer_results) do
      [
        {
          iaa: 'IAA123',
          issuer: service_provider.issuer,
          year_month: '202408',
        },
        {
          iaa: 'IAA123',
          issuer: service_provider.issuer,
          year_month: '202409',
        },
      ]
    end

    let(:by_partner_results) do
      []
    end

    let(:by_issuer_profile_age_results) do
      []
    end

    it 'does not error if by_iaa_results is missing an entry' do
      csv_data = report.combine_by_iaa_month(
        by_iaa_results:,
        by_issuer_results:,
        by_partner_results:,
        by_issuer_profile_age_results:,
      )

      csv = CSV.parse(csv_data, headers: true)
      expect(csv.length).to be
    end

    it 'logs a warning for which IAA and which month for debugging' do
      expect(Rails.logger).to receive(:warn) do |msg|
        expect(JSON.parse(msg, symbolize_names: true)).to eq(
          level: 'warning',
          name: 'missing iaa_results',
          iaa: 'IAA123',
          year_month: '202409',
        )
      end

      report.combine_by_iaa_month(
        by_iaa_results:,
        by_issuer_results:,
        by_partner_results:,
        by_issuer_profile_age_results:,
      )
    end
  end

  def build_iaa_order(order_number:, date_range:, iaa_gtc:)
    create(
      :iaa_order,
      order_number: order_number,
      start_date: date_range.begin,
      end_date: date_range.end,
      iaa_gtc: iaa_gtc,
    )
  end

  def build_integration(issuer:, partner_account:)
    create(
      :integration,
      issuer: issuer,
      partner_account: partner_account,
    )
  end

  def create_sp_return_log(user:, issuer:, ial:, returned_at:)
    create(
      :sp_return_log,
      user_id: user.id,
      issuer: issuer,
      ial: ial,
      requested_at: returned_at,
      returned_at: returned_at,
      profile_verified_at: user.profiles.map(&:verified_at).max,
      billable: true,
    )
  end
end
