require 'rails_helper'
require 'csv'

RSpec.describe Reports::MonthlyAccountReuseReport do
  let(:report_date) { Date.new(2021, 3, 1) }

  subject(:report) { Reports::MonthlyAccountReuseReport.new }

  let(:s3_report_bucket_prefix) { 'reports-bucket' }
  let(:s3_report_path) do
    'int/monthly-account-reuse-report/2021/2021-03-01.monthly-account-reuse-report.json'
  end

  before do
    travel_to report_date
    allow(Identity::Hostdata).to receive(:env).and_return('int')
    allow(Identity::Hostdata).to receive(:aws_account_id).and_return('1234')
    allow(Identity::Hostdata).to receive(:aws_region).and_return('us-west-1')
    allow(IdentityConfig.store).to receive(:s3_report_bucket_prefix).
      and_return(s3_report_bucket_prefix)

    Aws.config[:s3] = {
      stub_responses: {
        put_object: {},
      },
    }
  end

  describe '#perform' do
    it 'uploads a file to S3 based on the report date' do
      expect(report).to receive(:upload_file_to_s3_bucket).with(
        path: s3_report_path,
        body: anything,
        content_type: 'text/csv',
        bucket: 'reports-bucket.1234-us-west-1',
      ).exactly(1).time.and_call_original

      expect(report).to receive(:report_body).and_call_original.once

      report.perform
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

      it 'aggregates by issuer' do
        expect(report).to receive(:upload_file_to_s3_bucket).
          exactly(1).times do |path:, body:, content_type:, bucket:|
            actual_csv = body
            expected_csv = CSV.generate do |csv|
              [
                [
                  { title: 'IDV app reuse rate Feb-2021', float_as_percent: true, precision: 4 },
                  ['Num. SPs', 'Num. users', 'Percentage'],
                  [2, 3, 0.3],
                  [3, 2, 0.2],
                  ['Total (all >1)', 5, 0.5],
                ],
                [
                  { title: 'Total proofed identities' },
                  ['Total proofed identities (Feb-2021)'],
                  [10],
                ],
              ].each do |row|
                csv << row
              end
            end
            expect(actual_csv).to eq(expected_csv)
          end

        report.perform
      end
    end
  end
end
