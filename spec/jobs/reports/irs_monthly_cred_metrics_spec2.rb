require 'rails_helper'

RSpec.describe Reports::IrsMonthlyCredMetricsReport do
  let(:report_date) { Date.new(2021, 3, 2).in_time_zone('UTC').end_of_day }
  subject(:report) { described_class.new(report_date) }

  let(:name) { 'irs-monthly-cred-metrics-report' }
  let(:s3_report_bucket_prefix) { 'reports-bucket' }
  let(:report_folder) do
    'int/irs-monthly-cred-metrics-report/2021/2021-03-02.irs-monthly-cred-metrics-report'
  end

  let(:expected_s3_paths) do
    [
      "#{report_folder}/irs_ial2_cred_created_by_email.csv",
      "#{report_folder}/irs_total_active_user_cred_counts.csv",
      "#{report_folder}/irs_ial2_cred_active_user_counts.csv",
    ]
  end

  let(:s3_metadata) do
    {
      body: anything,
      content_type: 'text/csv',
      bucket: 'reports-bucket.1234-us-west-1',
    }
  end

  let(:mock_all_login_emails) { ['irs_team@example.com'] }
  let(:mock_daily_reports_emails) { ['irs_ops@example.com'] }

  let(:mock_csv_data) { [['Metric', 'Value']] }

  before do
    allow(Identity::Hostdata).to receive(:env).and_return('int')
    allow(Identity::Hostdata).to receive(:aws_account_id).and_return('1234')
    allow(Identity::Hostdata).to receive(:aws_region).and_return('us-west-1')
    allow(IdentityConfig.store).to receive(:s3_report_bucket_prefix)
      .and_return(s3_report_bucket_prefix)

    Aws.config[:s3] = {
      stub_responses: {
        put_object: {},
      },
    }

    allow(report.irs_ial2_cred_created_by_email_report).to receive(:as_csv)
      .and_return(mock_csv_data)
    allow(report.irs_total_active_user_cred_counts_report).to receive(:as_csv)
      .and_return(mock_csv_data)
    allow(report.irs_ial2_cred_active_user_counts_report).to receive(:as_csv)
      .and_return(mock_csv_data)

    allow(IdentityConfig.store).to receive(:team_daily_reports_emails)
      .and_return(mock_daily_reports_emails)
    allow(IdentityConfig.store).to receive(:team_all_login_emails)
      .and_return(mock_all_login_emails)
  end

  it 'sends out a report to just the daily team' do
    expect(ReportMailer).to receive(:tables_report).once.with(
      email: anything,
      subject: 'IRS Monthly Credential Metrics Report - 2021-03-02',
      reports: anything,
      message: report.preamble,
      attachment_format: :xlsx,
    ).and_call_original

    report.perform(report_date)
  end

  context 'when queued from the first of the month' do
    let(:report_date) { Date.new(2021, 3, 1).prev_day }

    it 'sends out a report to everybody' do
      expect(ReportMailer).to receive(:tables_report).once.with(
        email: anything,
        subject: 'IRS Monthly Credential Metrics Report - 2021-02-28',
        reports: anything,
        message: report.preamble,
        attachment_format: :xlsx,
      ).and_call_original

      report.perform(report_date)
    end
  end

  it 'does not send out a report with no emails' do
    allow(IdentityConfig.store).to receive(:team_daily_reports_emails).and_return('')

    expect(report).to_not receive(:reports)
    expect(ReportMailer).not_to receive(:tables_report)

    report.perform(report_date)
  end

  it 'uploads a file to S3 based on the report date' do
    expected_s3_paths.each do |path|
      binding.pry
      expect(report).to receive(:upload_file_to_s3_bucket).with(
        path: path,
        **s3_metadata,
      ).exactly(1).time.and_call_original
    end

    report.perform(report_date)
  end

  describe '#emails' do
    context 'on the first of the month' do
      let(:report_date) { Date.new(2021, 3, 1).prev_day }

      it 'emails the whole login team' do
        expected_array = mock_daily_reports_emails + mock_all_login_emails
        expect(report.emails).to match_array(expected_array)
      end
    end

    context 'during the rest of the month' do
      let(:report_date) { Date.new(2021, 3, 2).prev_day }

      it 'only emails the daily report team' do
        expect(report.emails).to match_array(mock_daily_reports_emails)

      end
    end
  end

  describe '#preamble' do
    let(:env) { 'prod' }
    subject(:preamble) { report.preamble(env:) }

    it 'has a preamble that is valid HTML' do
      expect(preamble).to be_html_safe
      expect { Nokogiri::XML(preamble) { |config| config.strict } }.to_not raise_error
    end

    context 'in a non-prod environment' do
      let(:env) { 'staging' }

      it 'has an alert with the environment name' do
        expect(preamble).to be_html_safe
        doc = Nokogiri::XML(preamble)
        alert = doc.at_css('.usa-alert')
        expect(alert.text).to include(env)
      end
    end
  end
end