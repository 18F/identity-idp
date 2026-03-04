# frozen_string_literal: true

require 'rails_helper'
require 'active_support/testing/time_helpers'

RSpec.describe Reports::MonthlySpVerificationReport do
  include ActiveSupport::Testing::TimeHelpers

  let(:report_date)     { (Time.zone.today.beginning_of_month - 1.day).end_of_day }
  let(:report_receiver) { :internal }
  let(:report) { described_class.new(report_date, report_receiver) }
  let(:agency_abbreviation) { 'Test_agency' }

  let(:base_config) do
    {
      'issuers' => ['issuer1'],
      'agency_abbreviation' => agency_abbreviation,
      'partner_emails' => ['mock_partner@example.com'],
      'internal_emails' => ['mock_internal@example.com'],
    }
  end

  let(:mock_funnel_table) do
    [
      ['Metric', 'Count', 'Rate'],
      ['Verification Demand', 25, '100%'],
      ['Verification Failures', 10, '40%'],
      ['Verification Successes', 15, '60%'],
    ]
  end

  let(:dummy_report_data) { [%w[Header1 Header2], %w[Value1 Value2]] }

  before do
    travel_to(report_date + 1.day + 10.hours)

    allow(IdentityConfig.store).to receive(:sp_verification_report_configs)
      .and_return([base_config])

    allow(report).to receive(:bucket_name).and_return('my-test-bucket')
    allow(report).to receive(:generate_s3_paths).and_return([nil, 'reports/path.csv'])
    allow(report).to receive(:upload_file_to_s3_bucket).and_return(true)

    allow_any_instance_of(Reporting::SpVerificationReport)
      .to receive(:funnel_table)
      .and_return(mock_funnel_table)

    allow(ReportMailer).to receive(:tables_report)
      .and_return(double(deliver_now: true))
  end

  context 'receiver :both with partner emails present' do
    let(:report_receiver) { :both }
    let(:report_date)     { Date.new(2025, 10, 1).prev_day.end_of_day } # 2025-09-30

    it 'sends out a report to TO partner, BCC internal' do
      expect(ReportMailer).to receive(:tables_report).once.with(
        to: ['mock_partner@example.com'],
        bcc: ['mock_internal@example.com'],
        subject: "Monthly #{agency_abbreviation} Verification Report - 2025-09-30",
        reports: anything, # we don’t care about shape here
        message: report.preamble,
        attachment_format: :csv,
      ).and_return(double(deliver_now: true))

      report.perform(report_date, :both)
    end
  end

  context 'for any day of the month sends out the report to the internal' do
    let(:report_receiver) { :internal }
    let(:report_date)     { Date.new(2025, 9, 27).prev_day.end_of_day } # 2025-09-26

    it 'emails internal only' do
      expect(ReportMailer).to receive(:tables_report).once.with(
        to: ['mock_internal@example.com'],
        bcc: [],
        subject: "Monthly #{agency_abbreviation} Verification Report - 2025-09-26",
        reports: anything,
        message: report.preamble,
        attachment_format: :csv,
      ).and_return(double(deliver_now: true))

      report.perform(report_date, :internal)
    end
  end

  context 'receiver :both but partner emails empty' do
    let(:report_receiver) { :both }
    let(:report_date)     { Date.new(2025, 7, 1).prev_day.end_of_day } # 2025-06-30

    before do
      cfg = base_config.merge(
        'partner_emails' => [],
        'internal_emails' => ['mock_internal@example.com'],
      )
      allow(IdentityConfig.store).to receive(:sp_verification_report_configs).and_return([cfg])
    end

    it 'logs a warning and sends the report only to internal emails' do
      expect(Rails.logger).to receive(:warn).with(
        "Monthly #{agency_abbreviation} Verification Report: recipient is :both " \
        "but no external email specified",
      )

      expect(ReportMailer).to receive(:tables_report).once.with(
        to: ['mock_internal@example.com'],
        bcc: [],
        subject: "Monthly #{agency_abbreviation} Verification Report - 2025-06-30",
        reports: anything,
        message: report.preamble,
        attachment_format: :csv,
      ).and_return(double(deliver_now: true))

      report.perform(report_date, :both)
    end
  end

  context 'recipient is internal but internal emails are empty' do
    let(:report_receiver) { :internal }
    let(:report_date)     { Date.new(2021, 3, 2).in_time_zone('UTC').end_of_day }

    before do
      cfg = base_config.merge('partner_emails' => [], 'internal_emails' => [])
      allow(IdentityConfig.store).to receive(:sp_verification_report_configs).and_return([cfg])
    end

    it 'logs a warning and does not send the report' do
      expect(Rails.logger).to receive(:warn).with(
        "No email addresses received - Monthly #{agency_abbreviation} Verification Report NOT SENT",
      )
      expect(ReportMailer).not_to receive(:tables_report)
      expect(report).not_to receive(:sp_verification_report)

      report.perform(report_date, :internal)
    end
  end

  describe '#perform' do
    it 'uploads the report to S3 and sends the email' do
      expect(report).to receive(:upload_to_s3).at_least(:once)
      expect(ReportMailer).to receive(:tables_report)
      report.perform(report_date, :internal)
    end

    it 'iterates over all configured SP entries' do
      allow(IdentityConfig.store).to receive(:sp_verification_report_configs).and_return(
        [
          base_config.merge('agency_abbreviation' => 'Test_agency1'),
          base_config.merge('agency_abbreviation' => 'Test_agency2'),
        ],
      )

      expect(report).to receive(:send_report).twice
      report.perform(report_date, :internal)
    end
  end

  describe '#csv_file' do
    it 'builds CSV from rows' do
      csv = report.csv_file(dummy_report_data)
      expect(csv).to include('Header1,Header2')
      expect(csv).to include('Value1,Value2')
    end
  end

  describe '#sp_verification_report' do
    it 'constructs the lib with month range + args' do
      allow(report).to receive(:sp_verification_report).and_call_original

      # We still stub the funnel_table so no CW call happens when as_emailable_reports is later used
      expect(Reporting::SpVerificationReport).to receive(:new).with(
        time_range: report_date.all_month,
        issuers: ['issuer1'],
        agency_abbreviation: 'Test_agency',
      ).and_call_original

      # Build the instance so the expectation above is exercised
      inst = report.sp_verification_report(['issuer1'], 'Test_agency')
      expect(inst).to be_a(Reporting::SpVerificationReport)
    end
  end
end
