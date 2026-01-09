require 'rails_helper'

RSpec.describe Reports::SpRegistrationFunnelReport do
  let(:report_date)     { Date.new(2021, 3, 2).in_time_zone('UTC').end_of_day }
  let(:report_receiver) { :internal }
  subject(:report)  { described_class.new(report_date, report_receiver) }
  let(:agency_abbreviation) { 'Test_agency' }
  let(:report_name)         { "#{agency_abbreviation.downcase}_registration_funnel_report" }

  let(:s3_report_bucket_prefix) { 'reports-bucket' }

  let(:report_folder) do
    "int/#{report_name}/2021/2021-03-02.#{report_name}"
  end

  let(:expected_s3_paths) do
    [
      "#{report_folder}/definitions.csv",
      "#{report_folder}/overview.csv",
      "#{report_folder}/funnel_metrics.csv",
    ]
  end

  let(:s3_metadata) do
    {
      body: anything,
      content_type: 'text/csv',
      bucket: 'reports-bucket.1234-us-west-1',
    }
  end

  let(:internal_emails) { ['mock_internal@example.com'] }
  let(:partner_emails)  { ['mock_partner@example.com'] }

  let(:sp_configs) do
    [
      {
        'issuers'             => ['sp:example:issuer'],
        'agency_abbreviation' => agency_abbreviation,
        'partner_emails'      => partner_emails,
        'internal_emails'     => internal_emails,
      },
    ]
  end

  # Stub only the heavy table (avoids CloudWatch); leave definitions/overview real
  let(:mock_funnel_metrics_data) do
    [
      ['Metric', 'Number of accounts', '% of total from start'],
      ['Registration Demand', 100, '100%'],
      ['Registration Successes', 60,  '60%'],
      ['Registration Failures', 40,  '40%'],
    ]
  end

  before do
    allow(Identity::Hostdata).to receive(:env).and_return('int')
    allow(Identity::Hostdata).to receive(:aws_account_id).and_return('1234')
    allow(Identity::Hostdata).to receive(:aws_region).and_return('us-west-1')
    allow(IdentityConfig.store).to receive(:s3_report_bucket_prefix)
      .and_return(s3_report_bucket_prefix)

    Aws.config[:s3] = { stub_responses: { put_object: {} } }

    allow(IdentityConfig.store).to receive(:sp_registration_funnel_report_configs)
      .and_return(sp_configs)

    allow(report).to receive(:upload_file_to_s3_bucket).and_return(true)

    allow_any_instance_of(Reporting::SpRegistrationFunnelReport)
      .to receive(:funnel_metrics_table)
      .and_return(mock_funnel_metrics_data)
  end

  context 'recipient is :both but partner emails are empty' do
    let(:report_receiver) { :both }
    let(:report_date)     { Date.new(2025, 10, 20).prev_day } # 2025-10-19
    subject(:report)  { described_class.new(report_date, report_receiver) }

    let(:partner_emails)  { [] }
    let(:internal_emails) { ['mock_internal@example.com'] }

    it 'logs a warning and sends the report only to internal emails' do
      expect(Rails.logger).to receive(:warn).with(
        "#{agency_abbreviation} Registration Funnel Report: recipient is :both but no external email specified",
      )

      expect(ReportMailer).to receive(:tables_report).once.with(
        to: internal_emails,
        bcc:   [],
        subject: "#{agency_abbreviation} Registration Funnel Report - 2025-10-19",
        reports: kind_of(Array),
        message: report.preamble,
        attachment_format: :csv,
      ).and_call_original

      report.perform(report_date, :both)
    end
  end

  context 'recipient is :internal but internal emails are empty' do
    let(:report_receiver) { :internal }
    let(:report_date)     { Date.new(2021, 3, 2).in_time_zone('UTC').end_of_day }
    subject(:report)  { described_class.new(report_date, report_receiver) }

    let(:internal_emails) { [] }
    let(:partner_emails)  { ['mock_partner@example.com'] }

    it 'logs a warning and does not send the report' do
      expect(Rails.logger).to receive(:warn).with(
        "No email addresses received - #{agency_abbreviation} Registration Funnel Report NOT SENT",
      )

      expect(ReportMailer).not_to receive(:tables_report)
      expect(report).not_to receive(:reports)

      report.perform(report_date, :internal)
    end
  end

  it 'sends to internal only by default' do
    expect(ReportMailer).to receive(:tables_report).once.with(
      to: ['mock_internal@example.com'],
      bcc:   [],
      subject: "#{agency_abbreviation} Registration Funnel Report - 2021-03-02",
      reports: kind_of(Array),
      message: report.preamble,
      attachment_format: :csv,
    ).and_call_original

    report.perform(report_date)
  end

  it 'does not send out a report with no emails' do
    # Override configs: no recipients
    sp_configs_blank = [
      {
        'issuers'             => ['sp:example:issuer'],
        'agency_abbreviation' => agency_abbreviation,
        'partner_emails'      => [],
        'internal_emails'     => [],
      },
    ]
    allow(IdentityConfig.store).to receive(:sp_registration_funnel_report_configs)
      .and_return(sp_configs_blank)

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

  context 'begining of the week, it sends out the report to the internal and partner' do
    let(:report_date) { Date.new(2025, 10, 20).prev_day } # 2025-10-19
    subject(:report) { described_class.new(report_date, :both) }

    let(:partner_emails)  { ['mock_partner@example.com'] }
    let(:internal_emails) { ['mock_internal@example.com'] }

    it 'emails partner in TO and internal in BCC' do
      expect(ReportMailer).to receive(:tables_report).once.with(
        to: ['mock_partner@example.com'],
        bcc:   ['mock_internal@example.com'],
        subject: "#{agency_abbreviation} Registration Funnel Report - 2025-10-19",
        reports: kind_of(Array),
        message: report.preamble,
        attachment_format: :csv,
      ).and_call_original

      report.perform(report_date, :both)
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

  describe '#previous_week_range' do
    context 'report_date is sunday of new week' do
      let(:report_date) { Date.new(2025, 10, 12).in_time_zone('UTC').end_of_day }
      it 'returns a 7-day range starting from last Sunday' do
        range = report.previous_week_range
        expect(range).to be_a(Range)
        expect(range.first).to be < range.last
        expect(range.first.wday).to eq(0) # 0 =Sunday
        expect(range.last.wday).to eq(6) # 6 Monday
        expect((range.last.to_date - range.first.to_date).to_i).to eq(6)
      end
    end

    context 'report_date is middle of week' do
      let(:report_date) { Date.new(2025, 10, 9).in_time_zone('UTC').end_of_day }
      it 'returns a 7-day range starting from last Sunday' do
        range = report.previous_week_range
        expect(range).to be_a(Range)
        expect(range.first).to be < range.last
        expect(range.first.wday).to eq(0) # 0 =Sunday
        expect(range.last.wday).to eq(6) # 6 Monday
        expect((range.last.to_date - range.first.to_date).to_i).to eq(6)
      end
    end
  end
end
