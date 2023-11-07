require 'rails_helper'

RSpec.describe Reports::DailyRegistrationsReport do
  subject(:report) { Reports::DailyRegistrationsReport.new }

  let(:report_date) { Date.new(2021, 3, 1) }
  let(:s3_public_reports_enabled) { true }
  let(:s3_report_bucket_prefix) { 'reports-bucket' }
  let(:s3_report_public_bucket_prefix) { 'public-reports-bucket' }

  before do
    allow(Identity::Hostdata).to receive(:env).and_return('int')
    allow(Identity::Hostdata).to receive(:aws_account_id).and_return('1234')
    allow(Identity::Hostdata).to receive(:aws_region).and_return('us-west-1')
    allow(IdentityConfig.store).to receive(:s3_public_reports_enabled).
      and_return(s3_public_reports_enabled)
    allow(IdentityConfig.store).to receive(:s3_report_bucket_prefix).
      and_return(s3_report_bucket_prefix)
    allow(IdentityConfig.store).to receive(:s3_report_public_bucket_prefix).
      and_return(s3_report_public_bucket_prefix)

    Aws.config[:s3] = {
      stub_responses: {
        put_object: {},
      },
    }
  end

  describe '#perform' do
    it 'uploads a file to S3 based on the report date' do
      ['reports-bucket.1234-us-west-1', 'public-reports-bucket-int.1234-us-west-1'].each do |bucket|
        expect(report).to receive(:upload_file_to_s3_bucket).with(
          path: 'int/daily-registrations-report/2021/2021-03-01.daily-registrations-report.json',
          body: kind_of(String),
          content_type: 'application/json',
          bucket:,
        ).exactly(1).time.and_call_original
      end

      expect(report).to receive(:report_body).and_call_original.once

      report.perform(report_date)
    end

    context 'when s3 public reports are disabled' do
      let(:s3_public_reports_enabled) { false }

      it 'only uploads to one bucket' do
        expect(report).to receive(:upload_file_to_s3_bucket).with(
          hash_including(
            path: 'int/daily-registrations-report/2021/2021-03-01.daily-registrations-report.json',
            bucket: 'reports-bucket.1234-us-west-1',
          ),
        ).exactly(1).time.and_call_original

        report.perform(report_date)
      end
    end

    context 'with data' do
      let(:yesterday) { (report_date - 1).in_time_zone('UTC') }
      let(:two_days_ago) { (report_date - 2).in_time_zone('UTC') }

      before do
        # not fully registered
        create_list(:user, 2, created_at: yesterday)
        create_list(:user, 1, created_at: two_days_ago)

        # fully registered
        create_list(:user, 2, created_at: yesterday).each do |user|
          RegistrationLog.create(user:, registered_at: user.created_at)
        end
        create_list(:user, 1, created_at: two_days_ago).each do |user|
          RegistrationLog.create(user:, registered_at: user.created_at)
        end

        # deleted, counts as total users
        DeletedUser.create(
          user_created_at: two_days_ago,
          deleted_at: two_days_ago,
          uuid: SecureRandom.uuid,
          user_id: -1,
        )
      end

      it 'calculates users and fully registered users by day' do
        expect(report).to receive(:upload_file_to_s3_bucket).
          exactly(2).times do |path:, body:, content_type:, bucket:|
            parsed = JSON.parse(body, symbolize_names: true)

            expect(parsed[:finish]).to eq(report_date.end_of_day.as_json)
            expect(parsed[:results]).to match_array(
              [
                {
                  date: two_days_ago.to_date.as_json,
                  total_users: 3,
                  fully_registered_users: 1,
                  deleted_users: 1,
                },
                {
                  date: yesterday.to_date.as_json,
                  total_users: 4,
                  fully_registered_users: 2,
                  deleted_users: 0,
                },
              ],
            )
          end

        report.perform(report_date)
      end
    end
  end
end
