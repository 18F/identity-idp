require 'rails_helper'

RSpec.describe Reports::IrsVerificationDemographicsReport do
  let(:report_date) { Date.new(2021, 3, 2).in_time_zone('UTC').end_of_day }
  let(:report_receiver) { :internal }
  let(:time_range) { report_date.all_quarter }

  subject(:report) { described_class.new(report_date, report_receiver) }

  let(:job_report_name) { "#{agency_abbreviation.downcase}_verification_demographics_report" }
  let(:s3_report_bucket_prefix) { 'reports-bucket' }

  let(:report_folder) do
    "int/#{job_report_name}/2021/2021-03-02.#{job_report_name}"
  end
  let(:agency_abbreviation) { 'Test_Agency' }

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

  let(:internal_emails) { ['mock_internal@example.com'] }
  let(:partner_emails) { ['mock_feds@example.com', 'mock_contractors@example.com'] }
  let(:issuers) { ['issuer1'] }

  let(:sp_configs) do
    [
      {
        'issuers' => issuers,
        'agency_abbreviation' => agency_abbreviation,
        'partner_emails' => partner_emails,
        'internal_emails' => internal_emails,
      },
    ]
  end

  # Return "real-ish" emailable reports so ReportMailer doesn't explode on missing #title, etc
  let(:emailable_reports) do
    [
      Reporting::EmailableReport.new(
        title: 'Definitions',
        table: [['Metric', 'Unit', 'Definition']],
        filename: 'definitions',
      ),
      Reporting::EmailableReport.new(
        title: 'Overview',
        table: [['Report Timeframe', 'Report Generated', 'Issuer']],
        filename: 'overview',
      ),
      Reporting::EmailableReport.new(
        title: "#{agency_abbreviation} Age Metrics",
        table: mock_identity_verification_age_data,
        filename: 'age_metrics',
      ),
      Reporting::EmailableReport.new(
        title: "#{agency_abbreviation} State Metrics",
        table: mock_identity_verification_state_data,
        filename: 'state_metrics',
      ),
    ]
  end

  let(:mock_builder) do
    instance_double(
      Reporting::IrsVerificationDemographicsReport,
      age_metrics_table: mock_identity_verification_age_data,
      state_metrics_table: mock_identity_verification_state_data,
      as_emailable_reports: emailable_reports,
    )
  end

  before do
    allow(Identity::Hostdata).to receive(:env).and_return('int')
    allow(Identity::Hostdata).to receive(:aws_account_id).and_return('1234')
    allow(Identity::Hostdata).to receive(:aws_region).and_return('us-west-1')
    allow(IdentityConfig.store).to receive(:s3_report_bucket_prefix)
      .and_return(s3_report_bucket_prefix)

    Aws.config[:s3] = { stub_responses: { put_object: {} } }

    allow(IdentityConfig.store).to receive(:sp_verification_demographics_report_configs)
      .and_return(sp_configs)

    allow(report).to receive(:sp_verification_demographics_report).and_return(mock_builder)

    allow(ReportMailer).to receive_message_chain(:tables_report, :deliver_now)
  end

  context 'beginning of the quarter sends to internal + partner when receiver is :both' do
    let(:report_date) { Date.new(2025, 7, 1).prev_day } # 2025-06-30
    let(:report_receiver) { :both }
    subject(:report) { described_class.new(report_date, report_receiver) }

    it 'sends partner in TO and internal in BCC' do
      expect(ReportMailer).to receive(:tables_report).once.with(
        to: partner_emails,
        bcc: internal_emails,
        subject: "#{agency_abbreviation} Verification Demographics Report - 2025-06-30",
        reports: anything,
        message: report.preamble,
        attachment_format: :csv,
      ).and_call_original

      report.perform(report_date, :both)
    end
  end

  context 'any other day sends to internal when receiver is :internal' do
    let(:report_date) { Date.new(2025, 9, 27).prev_day } # 2025-09-26
    let(:report_receiver) { :internal }
    subject(:report) { described_class.new(report_date, report_receiver) }

    it 'sends only to internal emails' do
      expect(ReportMailer).to receive(:tables_report).once.with(
        to: internal_emails,
        bcc: [],
        subject: "#{agency_abbreviation} Verification Demographics Report - 2025-09-26",
        reports: anything,
        message: report.preamble,
        attachment_format: :csv,
      ).and_call_original

      report.perform(report_date, :internal)
    end
  end

  context 'recipient is :both but partner emails are empty' do
    let(:report_receiver) { :both }
    let(:report_date) { Date.new(2025, 7, 1).prev_day } # 2025-06-30
    subject(:report) { described_class.new(report_date, report_receiver) }

    let(:partner_emails) { [] }

    it 'logs a warning and sends only to internal' do
      expect(Rails.logger).to receive(:warn).with(
        "#{agency_abbreviation} Verification Demographics Report: " \
        "recipient is :both but no external email specified",
      )

      expect(ReportMailer).to receive(:tables_report).once.with(
        to: internal_emails,
        bcc: [],
        subject: "#{agency_abbreviation} Verification Demographics Report - 2025-06-30",
        reports: anything,
        message: report.preamble,
        attachment_format: :csv,
      ).and_call_original

      report.perform(report_date, :both)
    end
  end

  context 'recipient is :internal but internal emails are empty' do
    let(:report_receiver) { :internal }
    let(:internal_emails) { [] }

    it 'logs a warning and does not send the report' do
      expect(Rails.logger).to receive(:warn).with(
        "No emails received - #{agency_abbreviation} Verification Demographics Report NOT SENT",
      )

      expect(ReportMailer).not_to receive(:tables_report)
      expect(report).not_to receive(:reports)

      report.perform(report_date, :internal)
    end
  end

  it 'does not send when both internal and partner emails are empty' do
    allow(IdentityConfig.store).to receive(:sp_verification_demographics_report_configs).and_return(
      [
        {
          'issuers' => issuers,
          'agency_abbreviation' => agency_abbreviation,
          'partner_emails' => [],
          'internal_emails' => [],
        },
      ],
    )

    expect(report).not_to receive(:reports)
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
