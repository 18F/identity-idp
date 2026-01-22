require 'rails_helper'

RSpec.describe Reports::IrsOriginalVerificationDemographicsReport do
  let(:report_date) { Date.new(2021, 3, 2).in_time_zone('UTC').end_of_day }
  let(:report_receiver) { :internal }
  let(:time_range) { report_date.all_quarter }

  subject(:report) { Reports::IrsOriginalVerificationDemographicsReport.new(report_date, report_receiver) }

  let(:name) { 'irs-verification-demographics-report' }
  let(:s3_report_bucket_prefix) { 'reports-bucket' }
  let(:report_folder) do
    'int/irs-verification-demographics-report/2021/2021-03-02.irs-verification-demographics-report'
  end

  let(:expected_s3_paths) do
    [
      "#{report_folder}/definitions.csv",
      "#{report_folder}/overview.csv",
      "#{report_folder}/age_metrics.csv",
      "#{report_folder}/state_metrics.csv",
    ]
  end

  let(:s3_metadata) do
    {
      body: anything,
      content_type: 'text/csv',
      bucket: 'reports-bucket.1234-us-west-1',
    }
  end

  let(:mock_identity_verification_age_data) do
    [
      ['Age Range', 'User Count'],
      ['10-19', '2'],
      ['20-29', '2'],
      ['30-39', '2'],
    ]
  end

  let(:mock_identity_verification_state_data) do
    [
      ['State', 'User Count'],
      ['DE', '2'],
      ['MD', '2'],
      ['VA', '2'],
    ]
  end

  let(:mock_test_irs_demographic_emails) do
    ['mock_feds@example.com', 'mock_contractors@example.com']
  end
  let(:mock_test_internal_emails) { ['mock_internal@example.com'] }
  let(:mock_test_issuers) { ['issuer1'] }

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

    allow(IdentityConfig.store).to receive(:irs_verification_report_config)
      .and_return(mock_test_irs_demographic_emails)
    allow(IdentityConfig.store).to receive(:team_daily_reports_emails)
      .and_return(mock_test_internal_emails)

    allow(report.irs_verification_demographics_report).to receive(:age_metrics_table)
      .and_return(mock_identity_verification_age_data)

    allow(report.irs_verification_demographics_report).to receive(:state_metrics_table)
      .and_return(mock_identity_verification_state_data)
  end

  context 'for begining of the quarter sends out the report to the internal and partner' do
    let(:report_date) { Date.new(2025, 7, 1).prev_day }
    subject(:report) { described_class.new(report_date, :both) }
    it 'sends out a report to just to team data and partner' do
      expect(ReportMailer).to receive(:tables_report).once.with(
        to: ['mock_feds@example.com', 'mock_contractors@example.com'],
        bcc: ['mock_internal@example.com'],
        subject: 'IRS Verification Demographics Metrics Report - 2025-06-30',
        reports: anything,
        message: report.preamble,
        attachment_format: :csv,
      ).and_call_original

      report.perform(report_date, :both)
    end
  end

  context 'for any other day sends out the report to the internal' do
    let(:report_date) { Date.new(2025, 9, 27).prev_day }
    subject(:report) { described_class.new(report_date, :internal) }
    it 'sends out a report to just to team data' do
      expect(ReportMailer).to receive(:tables_report).once.with(
        to: ['mock_internal@example.com'],
        bcc: [],
        subject: 'IRS Verification Demographics Metrics Report - 2025-09-26',
        reports: anything,
        message: report.preamble,
        attachment_format: :csv,
      ).and_call_original

      report.perform(report_date, :internal)
    end
  end

  context 'when queued from the first of the month' do
    let(:report_date) { Date.new(2021, 3, 1).prev_day }

    it 'sends out a report to everybody' do
      expect(ReportMailer).to receive(:tables_report).once.with(
        to: ['mock_internal@example.com'],
        bcc: [],
        subject: 'IRS Verification Demographics Metrics Report - 2021-02-28',
        reports: anything,
        message: report.preamble,
        attachment_format: :csv,
      ).and_call_original

      report.perform(report_date)
    end
  end

  context 'recipient is both but IRS emails are empty' do
    let(:report_receiver) { :both }
    let(:report_date) { Date.new(2025, 7, 1).prev_day } # 2025-06-30
    subject(:report) { described_class.new(report_date, report_receiver) }

    before do
      allow(IdentityConfig.store).to receive(:irs_verification_report_config)
        .and_return([]) # no external IRS emails
      allow(IdentityConfig.store).to receive(:team_daily_reports_emails)
        .and_return(mock_test_internal_emails)
    end

    it 'logs a warning and sends the report only to internal emails' do
      expect(Rails.logger).to receive(:warn).with(
        'IRS Verification Demographics Report: recipient is :both but no external email specified',
      )

      expect(ReportMailer).to receive(:tables_report).once.with(
        to: ['mock_internal@example.com'],
        bcc: [],
        subject: 'IRS Verification Demographics Metrics Report - 2025-06-30',
        reports: anything,
        message: report.preamble,
        attachment_format: :csv,
      ).and_call_original

      report.perform(report_date, :both)
    end
  end

  context 'recipient is internal but internal emails are empty' do
    let(:report_receiver) { :internal }
    let(:report_date) { Date.new(2021, 3, 2).in_time_zone('UTC').end_of_day }
    subject(:report) { described_class.new(report_date, report_receiver) }

    before do
      allow(IdentityConfig.store).to receive(:team_daily_reports_emails)
        .and_return([]) # no internal emails
      allow(IdentityConfig.store).to receive(:irs_verification_report_config)
        .and_return(mock_test_irs_demographic_emails)
    end

    it 'logs a warning and does not send the report' do
      expect(Rails.logger).to receive(:warn).with(
        'No emails received - IRS Verification Demographics Report NOT SENT',
      )

      expect(ReportMailer).not_to receive(:tables_report)
      expect(report).not_to receive(:reports)

      report.perform(report_date, :internal)
    end
  end

  it 'does not send out a report with no emails' do
    allow(IdentityConfig.store).to receive(:irs_verification_report_config).and_return('')
    allow(IdentityConfig.store).to receive(:team_daily_reports_emails).and_return('')

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
