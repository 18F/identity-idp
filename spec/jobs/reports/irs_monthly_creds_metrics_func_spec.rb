require 'rails_helper'
require_relative '/Users/jabariamyles/identity-idp/app/jobs/reports/irs_monthly_cred_metrics_report.rb'
RSpec.describe Reports::IrsMonthlyCredMetricsReport do
  let(:report_date) { Date.new(2021, 3, 2).in_time_zone('UTC').end_of_day }
  subject(:report) { Reports::IrsMonthlyCredMetricsReport.new(report_date) }

  let(:name) { 'irs-monthly-cred-metrics' }
  let(:s3_report_bucket_prefix) { 'reports-bucket' }
  let(:report_folder) do
    'int/irs-monthly-cred-metrics/2021/2021-03-02.irs-monthly-cred-metrics'
  end

  let(:expected_s3_path) do
    "#{report_folder}/irs_monthly_cred_metrics.csv"
  end

  let(:s3_metadata) do
    {
      body: anything,
      content_type: 'text/csv',
      bucket: 'reports-bucket.1234-us-west-1',
    }
  end

  let(:mock_report_data) do
    [
      ['Issuer', 'IAA', 'Total Auths', 'Total Accounts'],
      ['issuer1', 'GTC123', 2, 2],
    ]
  end

  let(:mock_all_login_emails) { ['mock_feds@example.com'] }
  let(:mock_daily_reports_emails) { ['mock_irs@example.com'] }

  before do
    # App config/environment
    allow(Identity::Hostdata).to receive(:env).and_return('int')
    allow(Identity::Hostdata).to receive(:aws_account_id).and_return('1234')
    allow(Identity::Hostdata).to receive(:aws_region).and_return('us-west-1')
    allow(IdentityConfig.store).to receive(:s3_report_bucket_prefix).and_return(s3_report_bucket_prefix)
    allow(IdentityConfig.store).to receive(:team_all_login_emails).and_return(mock_all_login_emails)
    allow(IdentityConfig.store).to receive(:team_daily_reports_emails).and_return(mock_daily_reports_emails)

    # S3 stub
    Aws.config[:s3] = {
      stub_responses: {
        put_object: {},
      },
    }

    # Stub CSV generation
    allow(report).to receive(:as_csv).and_return(mock_report_data)

    # Minimal data for report to act on
    iaa = create(:integration_agreement, iaa_gtc: 'GTC123', issuer: 'issuer1')
    sp = create(:service_provider, issuer: 'issuer1', iaa: iaa)

    user1 = create(:user, confirmed_at: 2.days.ago)
    user2 = create(:user, confirmed_at: 3.days.ago)

    create(:service_provider_identity, user: user1, service_provider: sp, last_authenticated_at: 1.day.ago)
    create(:service_provider_identity, user: user2, service_provider: sp, last_authenticated_at: 1.day.ago)
  end

  it 'sends a report email on the 2nd of the month to the daily report team' do
    binding.pry
    expect(ReportMailer).to receive(:tables_report).once.with(
      email: anything,
      subject: 'IRS Monthly Credential Metrics Report - 2021-03-02',
      reports: anything,
      message: report.preamble,
      attachment_format: :xlsx,
    ).and_call_original

    report.perform(report_date)
  end

  context 'on the first of the month' do
    let(:report_date) { Date.new(2021, 3, 1).prev_day }

    it 'sends the report to the full login team' do
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

  it 'does not send the report if no emails are configured' do
    allow(IdentityConfig.store).to receive(:team_daily_reports_emails).and_return('')

    expect(ReportMailer).not_to receive(:tables_report)
    expect(report).not_to receive(:reports)

    report.perform(report_date)
  end

  it 'uploads the CSV report to S3' do
    expect(report).to receive(:upload_file_to_s3_bucket).with(
      path: expected_s3_path,
      **s3_metadata,
    ).once.and_call_original

    report.perform(report_date)
  end

  describe '#emails' do
    context 'on the first of the month' do
      let(:report_date) { Date.new(2021, 3, 1).prev_day }

      it 'includes both login team and daily report recipients' do
        expect(report.emails).to match_array(
          mock_daily_reports_emails + mock_all_login_emails,
        )
      end
    end

    context 'on other days' do
      it 'includes only daily report recipients' do
        expect(report.emails).to match_array(mock_daily_reports_emails)
      end
    end
  end

  describe '#preamble' do
    let(:env) { 'prod' }
    subject(:preamble) { report.preamble(env:) }

    it 'is valid HTML' do
      expect(preamble).to be_html_safe
      expect { Nokogiri::XML(preamble) { |c| c.strict } }.not_to raise_error
    end

    context 'in a non-prod env' do
      let(:env) { 'staging' }

      it 'shows an alert with the environment name' do
        doc = Nokogiri::XML(preamble)
        alert = doc.at_css('.usa-alert')
        expect(alert.text).to include('staging')
      end
    end
  end
end