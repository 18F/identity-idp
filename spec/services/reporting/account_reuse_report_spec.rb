require 'rails_helper'
require 'csv'

RSpec.describe Reporting::AccountReuseReport do
  let(:report_date) { Date.new(2021, 2, 28) }

  subject(:report) { Reporting::AccountReuseReport.new(report_date) }

  before do
    travel_to report_date
  end

  context 'with data' do
    let(:in_query) { report_date - 12.days }
    let(:out_of_query) { report_date + 12.days }

    let(:agency1) { create(:agency, name: 'The Agency') }
    let(:agency2) { create(:agency, name: 'The Other Agency') }
    let(:sp_a) { 'a' }
    let(:sp_b) { 'b' }
    let(:sp_c) { 'c' }
    let(:sp_d) { 'd' }
    let(:sp_e) { 'e' }
    let(:sp_f) { 'f' }
    let(:sp_g) { 'g' }
    let(:sp_h) { 'h' }
    let(:sp_i) { 'i' }
    let(:sp_j) { 'j' }
    let(:sp_k) { 'k' }
    let(:sp_l) { 'l' }

    let(:agency1_apps) { [sp_a, sp_d, sp_e, sp_h, sp_i, sp_l] }
    let(:all_agency_apps) do
      [sp_a, sp_b, sp_c, sp_d, sp_e, sp_f, sp_g, sp_h, sp_i, sp_j, sp_k, sp_l]
    end

    before do
      create(
        :service_provider,
        issuer: sp_a,
        iaa: 'iaa123',
        friendly_name: 'The App',
        agency: agency1,
      )
      create(
        :service_provider,
        issuer: sp_b,
        iaa: 'iaa456',
        friendly_name: 'The Other App',
        agency: agency2,
      )
      create(
        :service_provider,
        issuer: sp_c,
        iaa: 'iaa789',
        friendly_name: 'The Other Other App',
        agency: agency2,
      )
      create(
        :service_provider,
        issuer: sp_d,
        iaa: 'iaa321',
        friendly_name: 'The Other First App',
        agency: agency1,
      )
      create(
        :service_provider,
        issuer: sp_e,
        iaa: 'iaa123',
        friendly_name: 'App E',
        agency: agency1,
      )
      create(
        :service_provider,
        issuer: sp_f,
        iaa: 'iaa456',
        friendly_name: 'App F',
        agency: agency2,
      )
      create(
        :service_provider,
        issuer: sp_g,
        iaa: 'iaa789',
        friendly_name: 'App G',
        agency: agency2,
      )
      create(
        :service_provider,
        issuer: sp_h,
        iaa: 'iaa321',
        friendly_name: 'App H',
        agency: agency1,
      )
      create(
        :service_provider,
        issuer: sp_i,
        iaa: 'iaa123',
        friendly_name: 'App I',
        agency: agency1,
      )
      create(
        :service_provider,
        issuer: sp_j,
        iaa: 'iaa456',
        friendly_name: 'App J',
        agency: agency2,
      )
      create(
        :service_provider,
        issuer: sp_k,
        iaa: 'iaa789',
        friendly_name: 'App K',
        agency: agency2,
      )
      create(
        :service_provider,
        issuer: sp_l,
        iaa: 'iaa321',
        friendly_name: 'App L',
        agency: agency1,
      )

      # Seed the database with data to be queried
      #
      # User 1 has 3 SPs and 3 show up in the query
      # User 2 has 3 SPs and 3 show up in the query
      # User 3 has 3 SPs and only 2 show up in the query
      # User 4 has 2 SPs and 2 show up in the query
      # User 5 has 2 SPs and 2 show up in the query
      # User 6 has 2 SPs and only 1 shows up in the query
      # User 7 has 1 SP and 1 shows up in the query
      # User 8 has 1 SP and 0 show up in the query
      # User 9 has 2 SPs and only 1 shows up in the query
      # User 10 has 2 SPs and 0 show up in the query
      # User 11 has 2 SPs and 0 show up in the query
      # User 12 has 1 SP and 1 shows up in the query
      # User 13 has 1 SP and 0 show up in the query
      # User 14 has 1 SP and 0 show up in the query
      # User 15 has 12 SPs and 12 show up in the query
      # User 16 has 11 SPs and 11 show up in the query
      # User 17 has 11 SPs and 11 show up in the query
      # User 18 has 10 SPs and 10 show up in the query
      # User 19 has 10 SPs and 10 show up in the query
      # User 20 has 10 SPs and 9 show up in the query
      #
      # This will give 1 user with 3 SPs/apps and 3 users with 2 SPs/apps for the IDV app report
      # This will give 4 users with 3 SPs/apps and 5 users with 2 SPs/apps for the ALL app report
      # This will give 1 user with 9 SPs/apps for the ALL app report and 0 for the IDV app report
      # This will give 6 users with 10-12 SPs/apps for the ALL app report
      # This will give 5 users with 10-12 SPs/apps for the IDV app report
      # This will give 9 users with 2 agencies for the IDV agency report
      # This will give 13 users with 2 agencies for the ALL agency report

      mock_users_to_query = [
        { # 3 apps, 2 agencies
          created_timestamp: in_query,
          sp: all_agency_apps.first(3),
          sp_timestamp: Array.new(3) { in_query },
        },
        { # 3 apps, 2 agencies
          created_timestamp: in_query,
          sp: all_agency_apps.first(3),
          sp_timestamp: [in_query, in_query, out_of_query],
        },
        { # 3 apps, 2 agencies
          created_timestamp: in_query,
          sp: all_agency_apps.first(3),
          sp_timestamp: [in_query, out_of_query, out_of_query],
        },
        { # 3 apps, 2 agencies
          created_timestamp: in_query,
          sp: all_agency_apps.first(3),
          sp_timestamp: [in_query, out_of_query, out_of_query],
        },
        { # 3 apps, 2 agencies
          created_timestamp: out_of_query,
          sp: all_agency_apps.first(3),
          sp_timestamp: Array.new(3) { out_of_query },
        },
        { # 2 apps, 2 agencies
          created_timestamp: in_query,
          sp: all_agency_apps.first(2),
          sp_timestamp: Array.new(2) { in_query },
        },
        { # 2 apps, 1 agency
          created_timestamp: in_query,
          sp: agency1_apps.first(2),
          sp_timestamp: Array.new(2) { in_query },
        },
        { # 2 apps, 2 agencies
          created_timestamp: in_query,
          sp: all_agency_apps.first(2),
          sp_timestamp: [in_query, out_of_query],
        },
        { # 2 apps, 1 agency
          created_timestamp: in_query,
          sp: agency1_apps.first(2),
          sp_timestamp: [in_query, out_of_query],
        },
        { # 2 apps, 2 agencies
          created_timestamp: in_query,
          sp: all_agency_apps.first(2),
          sp_timestamp: Array.new(2) { out_of_query },
        },
        { # 2 apps, 2 agencies
          created_timestamp: out_of_query,
          sp: all_agency_apps.first(2),
          sp_timestamp: Array.new(2) { out_of_query },
        },
        { # 1 app, 1 agency
          created_timestamp: in_query,
          sp: [sp_a],
          sp_timestamp: [in_query],
        },
        { # 1 app, 1 agency
          created_timestamp: in_query,
          sp: [sp_a],
          sp_timestamp: [out_of_query],
        },
        { # 1 app, 1 agency
          created_timestamp: out_of_query,
          sp: [sp_a],
          sp_timestamp: [out_of_query],
        },
        { # 12 apps, 2 agencies
          created_timestamp: in_query,
          sp: all_agency_apps,
          sp_timestamp: Array.new(12) { in_query },
        },
        { # 11 apps, 2 agencies
          created_timestamp: in_query,
          sp: all_agency_apps.first(11),
          sp_timestamp: Array.new(11) { in_query },
        },
        { # 11 apps, 2 agencies
          created_timestamp: in_query,
          sp: all_agency_apps.first(11),
          sp_timestamp: Array.new(11) { in_query },
        },
        { # 10 apps, 2 agencies
          created_timestamp: in_query,
          sp: all_agency_apps.first(10),
          sp_timestamp: Array.new(10) { in_query },
        },
        { # 10 apps, 2 agencies
          created_timestamp: in_query,
          sp: all_agency_apps.first(10),
          sp_timestamp: Array.new(10) { in_query },
        },
        { # 10 apps, 2 agencies
          created_timestamp: in_query,
          sp: all_agency_apps.first(10),
          sp_timestamp: Array.new(9) { in_query } + Array.new(1) { out_of_query },
        },
        { # 3 apps, 2 agencies - Last user gets deleted
          created_timestamp: in_query,
          sp: all_agency_apps.first(3),
          sp_timestamp: Array.new(3) { in_query },
          deleted: true,
        },
      ]

      mock_users_to_query.each do |mock_user|
        current_user = create(:user, :fully_registered, registered_at: in_query)

        if mock_user[:deleted]
          DeletedUser.create_from_user(current_user)
          current_user.destroy!
        else
          create(
            :profile,
            :active,
            activated_at: in_query,
            user: current_user,
          )
        end

        mock_user[:sp].each_with_index do |sp, i|
          ServiceProviderIdentity.create(
            user_id: current_user.id,
            service_provider: sp,
            created_at: mock_user[:created_timestamp],
            last_ial2_authenticated_at: in_query,
            verified_at: mock_user[:sp_timestamp][i],
          )
        end
      end

      # Create active profiles that are out of query for total_proofed_identities
      10.times do
        create(
          :profile,
          :active,
          activated_at: out_of_query,
          user: create(:user, :fully_registered, registered_at: in_query),
        )
      end
    end

    describe '#account_reuse_emailable_report' do
      it 'has the correct results' do
        expected_csv = [
          ['Metric', 'Num. all users', '% of accounts', 'Num. IDV users', '% of accounts'],
          ['2 apps', 5, 5 / 30.0, 3, 3 / 20.0],
          ['3 apps', 4, 4 / 30.0, 1, 1 / 20.0],
          ['9 apps', 0, 0 / 30.0, 1, 1 / 20.0],
          ['10-12 apps', 6, 6 / 30.0, 5, 5 / 20.0],
          ['2+ apps', 15, 15 / 30.0, 10, 0.49999999999999994],
          ['2 agencies', 13, 13 / 30.0, 9, 9 / 20.0],
          ['2+ agencies', 13, 13 / 30.0, 9, 9 / 20.0],
        ]

        aggregate_failures do
          expect(report.account_reuse_emailable_report.title).to eq 'IDV app reuse rate Feb-2021'
          report.account_reuse_emailable_report.table.zip(expected_csv).each do |actual, expected|
            expect(actual).to eq(expected)
          end
        end
      end
    end
  end

  context 'without any data' do
    describe '#account_reuse_emailable_report' do
      it 'has the correct results' do
        expected_csv = [
          ['Metric', 'Num. all users', '% of accounts', 'Num. IDV users', '% of accounts'],
          ['0 apps', 0, 0, 0, 0],
          ['2+ apps', 0, 0, 0, 0],
          ['0 agencies', 0, 0, 0, 0],
          ['2+ agencies', 0, 0, 0, 0],
        ]

        aggregate_failures do
          report.account_reuse_emailable_report.table.zip(expected_csv).each do |actual, expected|
            expect(actual).to eq(expected)
          end
        end
      end
    end
  end
end
