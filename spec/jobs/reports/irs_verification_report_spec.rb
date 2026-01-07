require 'rails_helper'
require 'active_support/testing/time_helpers'

RSpec.describe Reports::IrsVerificationReport do
  include ActiveSupport::Testing::TimeHelpers

  let(:report_date) { Time.zone.today.end_of_day }
  let(:receiver) { :internal }
  let(:report) { described_class.new(report_date, receiver) }
  let(:dummy_report_data) { [['Header1', 'Header2'], ['Value1', 'Value2']] }
  let(:mock_test_irs_verification_emails) do
    ['mock_feds@example.com', 'mock_contractors@example.com']
  end
  let(:mock_test_internal_emails) { ['mock_internal@example.com'] }

  let(:mock_report_object) do
    instance_double(
      Reporting::IrsVerificationReport,
      as_emailable_reports: [
        Struct.new(:table, :filename).new(dummy_report_data, 'dummy.csv'),
      ],
    )
  end

  let(:mock_funnel_data) do
    [
      ['Metric', 'Number of accounts', '% of total from start'],
      ['Registration Demand', 25, '100%'],
      ['Registration Failures', 10, '40%'],
      ['Registration Successes', 15, '60%'],
    ]
  end

  before do
    travel_to Time.zone.parse('2025-05-13 10:00:00')

    allow(IdentityConfig.store).to receive(:irs_verification_report_config)
      .and_return(mock_test_irs_verification_emails)
    allow(IdentityConfig.store).to receive(:team_daily_reports_emails)
      .and_return(mock_test_internal_emails)

    allow(IdentityConfig.store).to receive(:irs_verification_report_issuers)
      .and_return(['issuer1'])

    allow(IdentityConfig.store).to receive(:team_all_login_emails)
      .and_return(['team@example.com'])

    allow(report).to receive(:upload_file_to_s3_bucket).and_return(true)
    allow(report).to receive(:bucket_name).and_return('my-test-bucket')
    allow(report.irs_verification_report).to receive(:funnel_table).and_return(mock_funnel_data)
    allow(ReportMailer).to receive_message_chain(:tables_report, :deliver_now)
  end

  after do
  end

  context 'begining of the week, it sends out the report to the internal and partner' do
    let(:report_date) { Date.new(2025, 10, 20).prev_day }
    subject(:report) { described_class.new(report_date, :both) }
    it 'sends out a report to just to team data and partner' do
      expect(ReportMailer).to receive(:tables_report).once.with(
        to: ['mock_feds@example.com', 'mock_contractors@example.com'],
        bcc: ['mock_internal@example.com'],
        subject: 'IRS Verification Report - 2025-10-19',
        reports: anything,
        message: report.preamble,
        attachment_format: :csv,
      ).and_call_original

      report.perform(report_date, :both)
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
        'IRS Verification Report: recipient is :both but no external email specified',
      )

      expect(ReportMailer).to receive(:tables_report).once.with(
        to: ['mock_internal@example.com'],
        bcc: [],
        subject: 'IRS Verification Report - 2025-06-30',
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
        .and_return(mock_test_irs_verification_emails)
    end

    it 'logs a warning and does not send the report' do
      expect(Rails.logger).to receive(:warn).with(
        'No email addresses received - IRS Verification Report NOT SENT',
      )

      expect(ReportMailer).not_to receive(:tables_report)
      expect(report).not_to receive(:reports)

      report.perform(report_date, :internal)
    end
  end

  describe '#perform' do
    it 'uploads the report to S3 and sends the email' do
      expect(report).to receive(:upload_to_s3).at_least(:once)
      expect(ReportMailer).to receive_message_chain(:tables_report, :deliver_now)

      report.perform(report_date)
    end

    it 'does not send an email when no addresses are configured' do
      allow(IdentityConfig.store).to receive(:irs_verification_report_config).and_return([])
      allow(IdentityConfig.store).to receive(:team_daily_reports_emails).and_return('')

      expect(ReportMailer).not_to receive(:tables_report)

      report.perform(report_date)
    end
  end

  describe '#preamble' do
    it 'includes non-prod warning in non-prod env' do
      html = report.preamble(env: 'dev')
      expect(html).to include('Non-Production Report')
      expect(html).to include('dev')
    end

    it 'returns empty string in prod' do
      html = report.preamble(env: 'prod')
      expect(html).not_to include('Non-Production Report')
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
