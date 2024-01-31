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

    let(:agency) { create(:agency, name: 'The Agency') }
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

    before do
      create(
        :service_provider,
        issuer: sp_a,
        iaa: 'iaa123',
        friendly_name: 'The App',
        agency: agency,
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
        agency: agency,
      )
      create(
        :service_provider,
        issuer: sp_e,
        iaa: 'iaa123',
        friendly_name: 'App E',
        agency: agency,
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
        agency: agency,
      )
      create(
        :service_provider,
        issuer: sp_i,
        iaa: 'iaa123',
        friendly_name: 'App I',
        agency: agency,
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
        agency: agency,
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
      #
      # This will give 1 user with 3 SPs/apps and 3 users with 2 SPs/apps for the IDV app report
      # This will give 4 users with 3 SPs/apps and 5 users with 2 SPs/apps for the ALL app report
      # This will give 3 users with 2 agencies for the IDV agency report
      # This will give 7 users with 2 agencies for the ALL agency report

      users_to_query = [
        { id: 1, # 3 apps, 2 agencies
          created_timestamp: in_query,
          sp: [sp_a, sp_b, sp_c],
          sp_timestamp: [in_query, in_query, in_query] },
        { id: 2, # 3 apps, 2 agencies
          created_timestamp: in_query,
          sp: [sp_a, sp_b, sp_c],
          sp_timestamp: [in_query, in_query, out_of_query] },
        { id: 3, # 3 apps, 2 agencies
          created_timestamp: in_query,
          sp: [sp_a, sp_b, sp_c],
          sp_timestamp: [in_query, out_of_query, out_of_query] },
        { id: 4, # 3 apps, 2 agencies
          created_timestamp: in_query,
          sp: [sp_a, sp_b, sp_c],
          sp_timestamp: [in_query, out_of_query, out_of_query] },
        { id: 5, # 3 apps, 2 agencies
          created_timestamp: out_of_query,
          sp: [sp_a, sp_b, sp_c],
          sp_timestamp: [out_of_query, out_of_query, out_of_query] },
        { id: 6, # 2 apps, 2 agencies
          created_timestamp: in_query,
          sp: [sp_a, sp_b],
          sp_timestamp: [in_query, in_query] },
        { id: 7, # 2 apps, 1 agency
          created_timestamp: in_query,
          sp: [sp_a, sp_d],
          sp_timestamp: [in_query, in_query] },
        { id: 8, # 2 apps, 2 agencies
          created_timestamp: in_query,
          sp: [sp_a, sp_b],
          sp_timestamp: [in_query, out_of_query] },
        { id: 9,  # 2 apps, 1 agency
          created_timestamp: in_query,
          sp: [sp_a, sp_d],
          sp_timestamp: [in_query, out_of_query] },
        { id: 10, # 2 apps, 2 agencies
          created_timestamp: in_query,
          sp: [sp_a, sp_b],
          sp_timestamp: [out_of_query, out_of_query] },
        { id: 11, # 2 apps, 2 agencies
          created_timestamp: out_of_query,
          sp: [sp_a, sp_b],
          sp_timestamp: [out_of_query, out_of_query] },
        { id: 12,
          created_timestamp: in_query,
          sp: [sp_a],
          sp_timestamp: [in_query] },
        { id: 13,
          created_timestamp: in_query,
          sp: [sp_a],
          sp_timestamp: [out_of_query] },
        { id: 14,
          created_timestamp: out_of_query,
          sp: [sp_a],
          sp_timestamp: [out_of_query] },
        { id: 15, # 12 apps, 2 agencies
          created_timestamp: in_query,
          sp: [sp_a, sp_b, sp_c, sp_d, sp_e, sp_f, sp_g, sp_h, sp_i, sp_j, sp_k, sp_l],
          sp_timestamp: [in_query, in_query, in_query, in_query, in_query, in_query, in_query,
                         in_query, in_query, in_query, in_query, in_query] },
        { id: 16, # 11 apps, 2 agencies
          created_timestamp: in_query,
          sp: [sp_a, sp_b, sp_c, sp_d, sp_e, sp_f, sp_g, sp_h, sp_i, sp_j, sp_k],
          sp_timestamp: [in_query, in_query, in_query, in_query, in_query, in_query, in_query,
                         in_query, in_query, in_query, in_query] },
        { id: 17, # 10 apps, 2 agencies
          created_timestamp: in_query,
          sp: [sp_a, sp_b, sp_c, sp_d, sp_e, sp_f, sp_g, sp_h, sp_i, sp_j],
          sp_timestamp: [in_query, in_query, in_query, in_query, in_query, in_query, in_query,
                         in_query, in_query, in_query] },
        { id: 18, # 10 apps, 2 agencies
          created_timestamp: in_query,
          sp: [sp_a, sp_b, sp_c, sp_d, sp_e, sp_f, sp_g, sp_h, sp_i, sp_j],
          sp_timestamp: [in_query, in_query, in_query, in_query, in_query, in_query, in_query,
                         in_query, in_query, in_query] },

      ]

      users_to_query.each do |user|
        user[:sp].each_with_index do |sp, i|
          ServiceProviderIdentity.create(
            user_id: user[:id],
            service_provider: sp,
            created_at: user[:created_timestamp],
            last_ial2_authenticated_at: in_query,
            verified_at: user[:sp_timestamp][i],
          )
        end
      end

      # Create active profiles for total_proofed_identities
      # These 13 profiles will yield 10 active profiles in the results
      (1..10).each do |_|
        create(
          :profile,
          :active,
          activated_at: in_query,
          user: create(:user, :fully_registered, registered_at: in_query),
        )
      end
      (1..5).each do
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
          ['2 apps', 5, 5 / 15.0, 3, 0.3],
          ['3 apps', 4, 4 / 15.0, 1, 0.1],
          ['10-12 apps', 4, 4 / 15.0, 4, 0.4],
          ['2+ apps', 13, 0.8666666666666666, 8, 0.8],
          ['2 agencies', 11, 11 / 15.0, 7, 0.7],
          ['2+ agencies', 11, 11 / 15.0, 7, 0.7],
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
