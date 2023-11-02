require 'rails_helper'

RSpec.describe Reports::MonthlyKeyMetricsReport do
  let(:report_date) { Date.new(2021, 3, 2) }
  subject(:report) { Reports::MonthlyKeyMetricsReport.new(report_date) }

  let(:name) { 'monthly-key-metrics-report' }
  let(:s3_report_bucket_prefix) { 'reports-bucket' }
  let(:report_folder) do
    'int/monthly-key-metrics-report/2021/2021-03-02.monthly-key-metrics-report'
  end

  let(:expected_s3_paths) do
    [
      "#{report_folder}/account_reuse.csv",
      "#{report_folder}/total_profiles.csv",
      "#{report_folder}/document_upload_proofing.csv",
      "#{report_folder}/account_deletion_rate.csv",
      "#{report_folder}/total_user_count.csv",
      "#{report_folder}/active_users_count.csv",
      "#{report_folder}/proofing_rate_metrics.csv",
      "#{report_folder}/agency_and_sp_counts.csv",
      "#{report_folder}/active_users_count_apg.csv",
    ]
  end

  let(:s3_metadata) do
    {
      body: anything,
      content_type: 'text/csv',
      bucket: 'reports-bucket.1234-us-west-1',
    }
  end

  let(:mock_proofing_report_data) do
    [
      ['metric', 'num_users', 'percent'],
    ]
  end

  let(:mock_proofing_rate_data) do
    [
      ['Metric', 'Trailing 30d', 'Trailing 60d', 'Trailing 90d'],
    ]
  end

  before do
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

    allow(report.monthly_proofing_report).to receive(:proofing_report).
      and_return(mock_proofing_report_data)
    allow(report.proofing_rate_report).to receive(:as_csv).
      and_return(mock_proofing_rate_data)
  end

  it 'sends out a report to the email listed with one total user' do
    expect(ReportMailer).to receive(:tables_report).once.with(
      email: [IdentityConfig.store.team_agnes_email],
      subject: 'Monthly Key Metrics Report - 2021-03-02',
      reports: anything,
      message: report.preamble,
      attachment_format: :xlsx,
    ).and_call_original

    report.perform(report_date)
  end

  it 'sends out a report to the emails listed with two users' do
    first_of_month_date = report_date - 1

    expect(ReportMailer).to receive(:tables_report).once.with(
      email: [
        IdentityConfig.store.team_agnes_email,
        IdentityConfig.store.team_all_feds_email,
        IdentityConfig.store.team_all_contractors_email,
      ],
      subject: 'Monthly Key Metrics Report - 2021-03-01',
      reports: anything,
      message: report.preamble,
      attachment_format: :xlsx,
    ).and_call_original

    report.perform(first_of_month_date)
  end

  it 'does not send out a report with no emails' do
    allow(IdentityConfig.store).to receive(:team_agnes_email).and_return('')

    expect_any_instance_of(Reporting::AccountReuseAndTotalIdentitiesReport).
      not_to receive(:total_identities_report)

    expect(ReportMailer).not_to receive(:tables_report)

    report.perform(report_date)
  end

  it 'uploads a file to S3 based on the report date' do
    expected_s3_paths.each do |path|
      expect(subject).to receive(:upload_file_to_s3_bucket).with(
        path: path,
        **s3_metadata,
      ).exactly(1).time.and_call_original
    end

    report.perform(report_date)
  end

  describe '#preamble' do
    subject(:preamble) { report.preamble }

    it 'has a preamble that is valid HTML' do
      expect(preamble).to be_html_safe

      expect { Nokogiri::XML(preamble) { |config| config.strict } }.to_not raise_error
    end
  end
end
