require 'rails_helper'

RSpec.describe Reports::MonthlyKeyMetricsReport do
  subject(:report) { Reports::MonthlyKeyMetricsReport.new }

  let(:report_date) { Date.new(2021, 3, 2) }
  let(:name) { 'monthly-key-metrics-report' }
  let(:agnes_email) { 'fake@agnes_email.com' }
  let(:feds_email) { 'fake@feds_email.com' }
  let(:s3_report_bucket_prefix) { 'reports-bucket' }
  let(:account_reuse_s3_path) do
    'int/monthly-key-metrics-report/2021/2021-03-02.monthly-key-metrics-report/account_reuse.csv'
  end
  let(:total_profiles_s3_path) do
    'int/monthly-key-metrics-report/2021/2021-03-02.monthly-key-metrics-report/total_profiles.csv'
  end
  let(:account_deletion_rate_s3_path) do
    'int/monthly-key-metrics-report/2021/2021-03-02.monthly-key-metrics-report/account_deletion_rate.csv'
  end

  before do
    allow(IdentityConfig.store).to receive(:team_agnes_email).
      and_return(agnes_email)
    allow(IdentityConfig.store).to receive(:team_all_feds_email).
      and_return(feds_email)

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

  it 'sends out a report to the email listed with one total user' do
    expect(ReportMailer).to receive(:tables_report).once.with(
      message: 'Report: monthly-key-metrics-report 2021-03-02',
      email: [agnes_email],
      subject: 'Monthly Key Metrics Report - 2021-03-02',
      tables: anything,
    ).and_call_original

    subject.perform(report_date)
  end

  it 'sends out a report to the emails listed with two users' do
    first_of_month_date = report_date - 1

    expect(ReportMailer).to receive(:tables_report).once.with(
      message: 'Report: monthly-key-metrics-report 2021-03-01',
      email: [agnes_email, feds_email],
      subject: 'Monthly Key Metrics Report - 2021-03-01',
      tables: anything,
    ).and_call_original

    subject.perform(first_of_month_date)
  end

  it 'does not send out a report with no emails' do
    allow(IdentityConfig.store).to receive(:team_agnes_email).and_return('')

    expect(ReportMailer).not_to receive(:tables_report).with(
      message: 'Report: monthly-key-metrics-report 2021-03-02',
      email: [''],
      subject: 'Monthly Key Metrics Report - 2021-03-02',
      tables: anything,
    ).and_call_original

    subject.perform(report_date)
  end

  it 'uploads a file to S3 based on the report date' do
    expect(subject).to receive(:upload_file_to_s3_bucket).with(
      path: account_reuse_s3_path,
      body: anything,
      content_type: 'text/csv',
      bucket: 'reports-bucket.1234-us-west-1',
    ).exactly(1).time.and_call_original

    expect(subject).to receive(:upload_file_to_s3_bucket).with(
      path: total_profiles_s3_path,
      body: anything,
      content_type: 'text/csv',
      bucket: 'reports-bucket.1234-us-west-1',
    ).exactly(1).time.and_call_original

    expect(subject).to receive(:upload_file_to_s3_bucket).with(
      path: account_deletion_rate_s3_path,
      body: anything,
      content_type: 'text/csv',
      bucket: 'reports-bucket.1234-us-west-1',
    ).exactly(1).time.and_call_original

    subject.perform(report_date)
  end
end
