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
    let(:agency3) { create(:agency, name: 'The Other Other Agency') }
    let(:sp_a) { 'a' }
    let(:sp_b) { 'b' }
    let(:sp_c) { 'c' }

    def create_identity(id, provider, verified_time)
      ServiceProviderIdentity.create(
        user_id: id, service_provider: provider,
        last_ial2_authenticated_at: in_query, verified_at: verified_time
      )
    end

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
        agency: agency3,
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
      # This will give 2 users with 3 SPs and 3 users with 2 SPs for the report

      users_to_query = [
        { id: 1, sp: [sp_a, sp_b, sp_c], timestamp: [in_query, in_query, in_query] },
        { id: 2, sp: [sp_a, sp_b, sp_c], timestamp: [in_query, in_query, in_query] },
        { id: 3, sp: [sp_a, sp_b, sp_c], timestamp: [in_query, in_query, out_of_query] },
        { id: 4, sp: [sp_a, sp_b], timestamp: [in_query, in_query] },
        { id: 5, sp: [sp_a, sp_b], timestamp: [in_query, in_query] },
        { id: 6, sp: [sp_a, sp_b], timestamp: [in_query, out_of_query] },
        { id: 7, sp: [sp_a], timestamp: [in_query] },
        { id: 8, sp: [sp_a], timestamp: [out_of_query] },
      ]

      users_to_query.each do |user|
        user[:sp].each_with_index do |sp, i|
          create_identity(user[:id], sp, user[:timestamp][i])
        end
      end

      # Create active profiles for total_proofed_identities
      # These 13 profiles will yield 10 active profiles in the results
      (1..10).each do |_|
        create(:profile, :active, activated_at: in_query)
      end
      (1..3).each do |_|
        create(:profile, :active, activated_at: out_of_query)
      end
    end

    describe '#account_reuse_emailable_report' do
      it 'has the correct data' do
        expect(report.account_reuse_emailable_report.table).to eq(
          [
            ["Metric", "Num. all users", "% of accounts", "Num. IDV users", "% of accounts"],
            ["2 apps", 3, 0.3, 3, 0.3],
            ["3 apps", 2, 0.2, 2, 0.2],
            ["2+ apps", 5, 0.5, 5, 0.5],
            ["2 agencies", 3, 0.3, 3, 0.3],
            ["3 agencies", 2, 0.2, 2, 0.2],
            ["2+ agencies", 5, 0.5, 5, 0.5],
          ],
        )
      end
    end
  end
end
