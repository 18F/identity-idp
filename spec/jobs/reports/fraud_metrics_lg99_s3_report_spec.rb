# To run these unit tests:
#
#   bundle exec rspec spec/jobs/reports/fraud_metrics_lg99_s3_report_spec.rb
#
# To run a specific example by line number (e.g. line 97):
#
#   bundle exec rspec spec/jobs/reports/fraud_metrics_lg99_s3_report_spec.rb:97
#
# See docs/local-development.md for general instructions on running tests locally.

require 'rails_helper'

RSpec.describe Reports::FraudMetricsLg99S3Report do
  let(:report_date) { Date.new(2021, 3, 2).in_time_zone('UTC').end_of_day }
  let(:report_receiver) { :internal }
  let(:time_range) { report_date.all_month }
  subject(:report) { Reports::FraudMetricsLg99S3Report.new(report_date, report_receiver) }

  let(:name) { 'fraud-metrics-lg99-s3-report' }
  let(:s3_report_bucket_prefix) { 'reports-bucket' }
  let(:s3_data_warehouse_bucket_prefix) { 'login-gov-dw-reports' }
  let(:report_folder) do
    'int/fraud-metrics-lg99-s3-report/2021/2021-03-02.fraud-metrics-lg99-s3-report'
  end

  let(:expected_s3_paths) do
    [
      "#{report_folder}/lg99_metrics.csv",
      "#{report_folder}/suspended_metrics.csv",
      "#{report_folder}/reinstated_metrics.csv",
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
      ['Unique users seeing LG-99', 5, time_range.begin.to_s,
       time_range.end.to_s],
    ]
  end
  let(:mock_suspended_metrics_table) do
    [
      ['Metric', 'Total', 'Range Start', 'Range End'],
      ['Unique users suspended', 2, time_range.begin.to_s,
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
      ['Unique users reinstated', 1, time_range.begin.to_s,
       time_range.end.to_s],
      ['Average Days to Reinstatement', 3.0, time_range.begin.to_s,
       time_range.end.to_s],
    ]
  end

  let(:mock_team_fraud_emails) { ['mock_feds@example.com', 'mock_contractors@example.com'] }
  let(:mock_test_fraud_emails) { ['mock_agnes@example.com', 'mock_daily@example.com'] }

  before do
    allow(Identity::Hostdata).to receive(:env).and_return('int')
    allow(Identity::Hostdata).to receive(:aws_account_id).and_return('1234')
    allow(Identity::Hostdata).to receive(:aws_region).and_return('us-west-1')
    allow(IdentityConfig.store).to receive(:s3_report_bucket_prefix)
      .and_return(s3_report_bucket_prefix)
    allow(IdentityConfig.store).to receive(:s3_data_warehouse_bucket_prefix)
      .and_return(s3_data_warehouse_bucket_prefix)

    Aws.config[:s3] = {
      stub_responses: {
        put_object: {},
      },
    }

    allow(IdentityConfig.store).to receive(:team_daily_fraud_metrics_emails)
      .and_return(mock_test_fraud_emails)
    allow(IdentityConfig.store).to receive(:team_monthly_fraud_metrics_emails)
      .and_return(mock_team_fraud_emails)

    allow(report.fraud_metrics_lg99_report_s3).to receive(:lg99_metrics_table)
      .and_return(mock_identity_verification_lg99_data)

    allow(report.fraud_metrics_lg99_report_s3).to receive(:suspended_metrics_table)
      .and_return(mock_suspended_metrics_table)

    allow(report.fraud_metrics_lg99_report_s3).to receive(:reinstated_metrics_table)
      .and_return(mock_reinstated_metrics_table)
  end

  it 'does not send out a report with no emails' do
    allow(IdentityConfig.store).to receive(:team_daily_fraud_metrics_emails).and_return('')

    expect(report).to_not receive(:reports)

    expect(ReportMailer).not_to receive(:tables_report)

    report.perform(report_date)
  end

  describe '#emails' do
    context 'on the first of the month' do
      let(:report_date) { Date.new(2021, 3, 1).prev_day }

      it 'emails the whole fraud team' do
        expected_array = mock_test_fraud_emails
        expected_array += mock_team_fraud_emails

        expect(report.emails).to match_array(expected_array)
      end
    end

    context 'during the rest of the month' do
      let(:report_date) { Date.new(2021, 3, 2).prev_day }
      it 'only emails test_fraud_reports' do
        expect(report.emails).to match_array(
          mock_test_fraud_emails,
        )
      end
    end
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

  describe '#reports' do
    it 'is memoized' do
      result1 = report.reports
      result2 = report.reports
      expect(result1).to equal(result2)
    end
  end

  describe '#fraud_metrics_lg99_report_s3' do
    it 'creates an instance with correct params' do
      fresh_report = Reports::FraudMetricsLg99S3Report.new(report_date)
      expect(Reporting::FraudMetricsLg99ReportS3).to receive(:new).with(
        time_range: report_date.all_month,
        bucket_name: 'login-gov-dw-reports-int-1234-us-west-1',
        report_date: report_date.to_date,
      ).and_call_original

      fresh_report.fraud_metrics_lg99_report_s3
    end

    it 'is memoized' do
      result1 = report.fraud_metrics_lg99_report_s3
      result2 = report.fraud_metrics_lg99_report_s3
      expect(result1).to equal(result2)
    end
  end

  describe '#upload_to_s3' do
    context 'when bucket_name is blank' do
      before do
        allow(report).to receive(:bucket_name).and_return(nil)
      end

      it 'does not upload to S3' do
        expect(report).not_to receive(:upload_file_to_s3_bucket)
        report.upload_to_s3([['A', 'B']], report_name: 'test')
      end
    end
  end

  describe '#csv_file' do
    it 'generates valid CSV from a 2D array' do
      expect(report.csv_file([['A', 'B'], ['1', '2']])).to eq("A,B\n1,2\n")
    end
  end

  describe '#data_warehouse_bucket_name' do
    it 'constructs the bucket name from config and hostdata' do
      expect(report.send(:data_warehouse_bucket_name)).to \
        eq('login-gov-dw-reports-int-1234-us-west-1')
    end
  end

  describe 'REPORT_NAME' do
    it 'has the expected constant value' do
      expect(described_class::REPORT_NAME).to eq('fraud-metrics-lg99-s3-report')
    end
  end
end
