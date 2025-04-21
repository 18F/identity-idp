require 'rails_helper'

RSpec.describe IrsReports::FraudMetricsReport do
  let(:report_date) { Date.new(2021, 3, 2).in_time_zone('UTC').end_of_day }
  let(:time_range) { report_date.all_month }
  subject(:report) { IrsReports::FraudMetricsReport.new(report_date) }

  let(:name) { 'fraud-metrics-report' }
  let(:s3_report_bucket_prefix) { 'reports-bucket' }
  let(:report_folder) do
    'int/fraud-metrics-report/2021/2021-03-02.fraud-metrics-report'
  end

  let(:expected_s3_paths) do
    [
      "#{report_folder}/#{issuer}_definitions.csv",
      "#{report_folder}/#{issuer}_overview.csv",
      "#{report_folder}/#{issuer}_fraud_metrics.csv",
      "#{report_folder}/#{issuer}_suspended_metrics.csv",
      "#{report_folder}/#{issuer}_reinstated_metrics.csv",
    ]
  end

  let(:s3_metadata) do
    {
      body: anything,
      content_type: 'text/csv',
      bucket: 'reports-bucket.1234-us-west-1',
    }
  end

  let(:mock_definitions_table) do
    [
      ['Metric', 'Unit', 'Definition'],
      ['Fraud Rules Catch Rate', 'Count', 'The count of unique accounts flagged for fraud review.'],
      ['Fraudulent credentials disabled', 'Count', 'The count of unique accounts suspended due to suspected fraudulent activity within the reporting month.'],
      ['Fraudulent credentials reinstated', 'Count', 'The count of unique suspended accounts that are reinstated within the reporting month.'],
    ]
  end
  
  let(:mock_overview_table) do
    [
      ['Report Timeframe', "#{time_range.begin} to #{time_range.end}"],
      # This needs to be Date.today so it works when run on the command line
      ['Report Generated', Date.today.to_s],
      ['Issuer', ':some:issuer'],
    ]
  end
  
  let(:mock_identity_verification_fraud_table) do
    [
      ['Metric', 'Total', 'Range Start', 'Range End'],
      ['Fraud Rules Catch Rate', 5, time_range.begin.to_s,
       time_range.end.to_s],
    ]
  end
  let(:mock_suspended_metrics_table) do
    [
      ['Metric', 'Total', 'Range Start', 'Range End'],
      ['Fraudulent credentials disabled', 2, time_range.begin.to_s,
       time_range.end.to_s],
      ['Average Days Creation to Suspension', 1.5, time_range.begin.to_s,
       time_range.end.to_s],
      ['Average Days Proofed to Suspension', 2.0, time_range.begin.to_s,
       time_range.end.to_s],
    ]
  end
  let(:mock_reinstated_metrics_table) do
    [
      ['Metric', 'Total', 'Range Start', 'Range End'],
      ['Fraudulent credentials reinstated', 1, time_range.begin.to_s,
       time_range.end.to_s],
      ['Average Days to Reinstatement', 3.0, time_range.begin.to_s,
       time_range.end.to_s],
    ]
  end

  let(:issuer) { 'urn:gov:gsa:openidconnect.profiles:sp:sso:agency_name:app_name' }
  let(:mock_emails) { ['mock_feds@example.com', 'mock_contractors@example.com'] }

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

    allow(IdentityConfig.store).to receive(:monthly_fraud_metrics_report_config)
      .and_return([{ 'emails' => mock_emails, 'issuers' => [issuer] }])

    mock_fraud_metrics = instance_double(
      IrsReporting::FraudMetricsLg99Report,
      as_emailable_reports: [
        Reporting::EmailableReport.new(title: 'Definitions', filename: 'definitions', table: mock_definitions_table),
        Reporting::EmailableReport.new(title: 'Overview', filename: 'overview', table: mock_overview_table),
        Reporting::EmailableReport.new(title: 'Fraud Metrics', filename: 'fraud_metrics', table: mock_identity_verification_fraud_table),
        Reporting::EmailableReport.new(title: 'Suspended User Metrics', filename: 'suspended_metrics',  table: mock_suspended_metrics_table),
        Reporting::EmailableReport.new(title: 'Reinstated User Metrics', filename: 'reinstated_metrics', table: mock_reinstated_metrics_table),
      ],
    )
    
    allow(IrsReporting::FraudMetricsLg99Report).to receive(:new).and_return(mock_fraud_metrics)

    # ensures uploads actually occur
    allow(report).to receive(:bucket_name).and_return('reports-bucket.1234-us-west-1')
  end

  it 'sends out a report to just to team data' do
    expect(ReportMailer).to receive(:tables_report).once.with(
      hash_including(
        email: match_array(mock_emails),
        subject: "Fraud Metrics Report - #{report_date.to_date}",
      )
    ).and_call_original

    report.perform(report_date)
  end

  context 'when the config entry has no e-mail addresses' do
    before do
      allow(IdentityConfig.store).to receive(:monthly_fraud_metrics_report_config)
        .and_return([{ 'emails' => [], 'issuers' => [issuer] }])
    end
    
    it 'does not attempt to build or send a report' do
      expect(IrsReporting::FraudMetricsLg99Report).not_to receive(:new)
      expect(ReportMailer).not_to receive(:tables_report)

      report.perform(report_date)
    end
  end

  it 'uploads one CSV per worksheet to S3 using issuer-prefixed filenames' do
    expected_s3_paths.each do |path|
      expect(report).to receive(:upload_file_to_s3_bucket).with(
        path: path,
        **s3_metadata,
      ).once.and_call_original
    end

    report.perform(report_date)
  end


  describe '#preamble' do
    subject(:preamble) { report.preamble(env:) }

    context 'in prod' do
      let(:env) { 'prod' }

      it { is_expected.to be_blank }
    end

    context 'in a non‑prod environment' do
      let(:env) { 'staging' }

      it 'contains an HTML alert naming the env' do
        expect(preamble).to be_html_safe
        doc = Nokogiri::XML(preamble)
        expect(doc.at_css('.usa-alert').text).to include(env)
      end
    end
  end
end
