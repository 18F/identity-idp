require 'rails_helper'

RSpec.describe Reports::SpFraudMetricsReport do
  let(:report_date) { Date.new(2021, 3, 2).in_time_zone('UTC').end_of_day }
  let(:time_range)  { report_date.all_month }
  let(:report_receiver) { :internal }

  subject(:report) { described_class.new(report_date, report_receiver) }

  let(:agency_abbreviation) { 'Test_Agency' }
  let(:report_name) { "#{agency_abbreviation.downcase}_fraud_metrics_report" }

  let(:s3_report_bucket_prefix) { 'reports-bucket' }

  let(:report_folder) do
    # env / report_name / year / date.report_name
    "int/#{report_name}/2021/2021-03-02.#{report_name}"
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

  let(:mock_lg99_metrics_data) do
    [
      ['Metric', 'Total', 'Range Start', 'Range End'],
      ['Fraud Rules Catch Count', 5, time_range.begin.to_s, time_range.end.to_s],
      ['Credentials Disabled', 2, time_range.begin.to_s, time_range.end.to_s],
      ['Credentials Reinstated', 1, time_range.begin.to_s, time_range.end.to_s],
    ]
  end

  let(:mock_partner_emails)  { ['mock_feds@example.com', 'mock_contractors@example.com'] }
  let(:mock_internal_emails) { ['mock_internal@example.com'] }
  let(:mock_fraud_issuers)   { ['issuer1'] }

  let(:sp_fraud_metrics_config) do
    [
      {
        'issuers' => mock_fraud_issuers,
        'agency_abbreviation' => agency_abbreviation,
        'partner_emails' => mock_partner_emails,
        'internal_emails' => mock_internal_emails,
      },
    ]
  end

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

    # Config used by the SP job
    allow(IdentityConfig.store).to receive(:sp_fraud_metrics_report_configs)
      .and_return(sp_fraud_metrics_config)

    # Avoid CloudWatch: just stub the metrics table for the underlying report
    allow_any_instance_of(Reporting::SpFraudMetricsLg99Report)
      .to receive(:lg99_metrics_table).and_return(mock_lg99_metrics_data)
  end

  context 'when recipient is :both and partner emails exist' do
    let(:report_date) { Date.new(2025, 10, 1).prev_day } # 2025-09-30
    subject(:report) { described_class.new(report_date, :both) }

    it 'sends a report to partner as TO and internal as BCC' do
      expect(ReportMailer).to receive(:tables_report).once.with(
        to: ['mock_feds@example.com', 'mock_contractors@example.com'],
        bcc: ['mock_internal@example.com'],
        subject: 'Test_Agency Fraud Metrics Report - 2025-09-30',
        reports: anything,
        message: report.preamble,
        attachment_format: :csv,
      ).and_call_original

      report.perform(report_date, :both)
    end
  end

  context 'recipient is :both but partner emails are empty' do
    let(:report_receiver) { :both }
    let(:report_date) { Date.new(2025, 9, 30).in_time_zone('UTC').end_of_day }
    subject(:report) { described_class.new(report_date, report_receiver) }

    let(:sp_fraud_metrics_config) do
      [
        {
          'issuers' => mock_fraud_issuers,
          'agency_abbreviation' => agency_abbreviation,
          'partner_emails' => [],
          'internal_emails' => mock_internal_emails,
        },
      ]
    end

    it 'logs a warning and sends the report to internal only' do
      expect(Rails.logger).to receive(:warn).with(
        'Test_Agency Fraud Metrics Report: recipient is :both but no external email specified',
      )

      expect(ReportMailer).to receive(:tables_report).once.with(
        to: ['mock_internal@example.com'],
        bcc: [],
        subject: 'Test_Agency Fraud Metrics Report - 2025-09-30',
        reports: anything,
        message: report.preamble,
        attachment_format: :csv,
      ).and_call_original

      report.perform(report_date, :both)
    end
  end

  context 'recipient is :internal but internal emails are empty' do
    let(:report_receiver) { :internal }
    let(:report_date) { Date.new(2025, 9, 30).in_time_zone('UTC').end_of_day }
    subject(:report) { described_class.new(report_date, report_receiver) }

    let(:sp_fraud_metrics_config) do
      [
        {
          'issuers' => mock_fraud_issuers,
          'agency_abbreviation' => agency_abbreviation,
          'partner_emails' => mock_partner_emails,
          'internal_emails' => [],
        },
      ]
    end

    it 'does not send a report' do
      expect(Rails.logger).to receive(:warn).with(
        'No email addresses received - Test_Agency Fraud Metrics Report NOT SENT',
      )

      expect(ReportMailer).not_to receive(:tables_report)

      report.perform(report_date, :internal)
    end
  end

  context 'recipient is :internal and internal emails exist' do
    let(:report_date) { Date.new(2025, 9, 27).prev_day } # 2025-09-26
    subject(:report) { described_class.new(report_date, :internal) }

    it 'sends a report to internal only' do
      expect(ReportMailer).to receive(:tables_report).once.with(
        to: ['mock_internal@example.com'],
        bcc: [],
        subject: 'Test_Agency Fraud Metrics Report - 2025-09-26',
        reports: anything,
        message: report.preamble,
        attachment_format: :csv,
      ).and_call_original

      report.perform(report_date, :internal)
    end
  end

  it 'does not send out a report if both internal and partner emails are empty' do
    empty_config = [
      {
        'issuers' => mock_fraud_issuers,
        'agency_abbreviation' => agency_abbreviation,
        'partner_emails' => [],
        'internal_emails' => [],
      },
    ]

    allow(IdentityConfig.store).to receive(:sp_fraud_metrics_report_configs)
      .and_return(empty_config)

    expect(report).not_to receive(:reports)
    expect(ReportMailer).not_to receive(:tables_report)

    expect(Rails.logger).to receive(:warn).with(
      'No email addresses received - Test_Agency Fraud Metrics Report NOT SENT',
    )

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
