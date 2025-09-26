require 'rails_helper'

RSpec.describe Reports::IrsFraudMetricsReport do
  let(:report_date) { Date.new(2021, 3, 2).in_time_zone('UTC').end_of_day }
  let(:time_range) { report_date.all_month }
  subject(:report) { Reports::IrsFraudMetricsReport.new(report_date) }

  let(:name) { 'irs-fraud-metrics-report' }
  let(:s3_report_bucket_prefix) { 'reports-bucket' }
  let(:report_folder) do
    'int/irs-fraud-metrics-report/2021/2021-03-02.irs-fraud-metrics-report'
  end

  let(:expected_s3_paths) do
    [
      "#{report_folder}/definitions.csv",
      "#{report_folder}/overview.csv",
      "#{report_folder}/lg99_metrics.csv",
    ]
  end

  let(:s3_metadata) do
    {
      body: anything,
      content_type: 'text/csv',
      bucket: 'reports-bucket.1234-us-west-1',
    }
  end

  let(:mock_identity_verification_lg99_data) do
    [
      ['Metric', 'Total', 'Range Start', 'Range End'],
      ['Fraud Rules Catch Count', 5, time_range.begin.to_s,
       time_range.end.to_s],
      ['Credentials Disabled', 2, time_range.begin.to_s,
       time_range.end.to_s],
      ['Credentials Reinstated', 1, time_range.begin.to_s,
       time_range.end.to_s],
    ]
  end

  let(:mock_test_fraud_emails) { ['mock_feds@example.com', 'mock_contractors@example.com'] }
  let(:mock_test_fraud_issuers) { ['issuer1'] }

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

    allow(IdentityConfig.store).to receive(:irs_fraud_metrics_emails)
      .and_return(mock_test_fraud_emails)

    allow(report.irs_fraud_metrics_lg99_report).to receive(:lg99_metrics_table)
      .and_return(mock_identity_verification_lg99_data)
  end

  it 'sends out a report to just to team data' do
    expect(ReportMailer).to receive(:tables_report).once.with(
      email: anything,
      subject: 'IRS Fraud Metrics Report - 2021-03-02',
      reports: anything,
      message: report.preamble,
      attachment_format: :csv,
    ).and_call_original

    report.perform(report_date)
  end

  context 'when queued from the first of the month' do
    let(:report_date) { Date.new(2021, 3, 1).prev_day }

    it 'sends out a report to everybody' do
      expect(ReportMailer).to receive(:tables_report).once.with(
        email: anything,
        subject: 'IRS Fraud Metrics Report - 2021-02-28',
        reports: anything,
        message: report.preamble,
        attachment_format: :csv,
      ).and_call_original

      report.perform(report_date)
    end
  end

  it 'does not send out a report with no emails' do
    allow(IdentityConfig.store).to receive(:irs_fraud_metrics_emails).and_return('')

    expect(report).to_not receive(:reports)

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
    let(:env) { 'prod' }
    subject(:preamble) { report.preamble(env:) }

    it 'has a blank preamble' do
      expect(preamble).to be_blank
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
