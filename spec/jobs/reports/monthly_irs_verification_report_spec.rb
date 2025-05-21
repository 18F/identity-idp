# frozen_string_literal: true

require 'rails_helper'
require 'active_support/testing/time_helpers'

RSpec.describe Reports::MonthlyIrsVerificationReport do
  include ActiveSupport::Testing::TimeHelpers

  let(:report_date) { (Time.zone.today.beginning_of_month - 1.day).end_of_day }
  let(:report) { described_class.new(report_date) }
  let(:dummy_report_data) { [['Header1', 'Header2'], ['Value1', 'Value2']] }

  let(:mock_report_object) do
    instance_double(
      Reporting::IrsVerificationReport,
      as_emailable_reports: [
        Struct.new(:table, :filename).new(dummy_report_data, 'dummy.csv'),
      ],
    )
  end

  before do
    # Travel to the 1st of the month at 10 AM (day after report_date)
    travel_to(report_date + 1.day + 10.hours)

    allow(IdentityConfig.store).to receive(:irs_verification_report_config)
      .and_return(['test@example.com'])

    allow(IdentityConfig.store).to receive(:irs_verification_report_issuers)
      .and_return(['issuer1'])

    allow(IdentityConfig.store).to receive(:team_all_login_emails)
      .and_return(['team@example.com'])

    allow(Reporting::IrsVerificationReport).to receive(:new).and_return(mock_report_object)
    allow(report).to receive(:upload_file_to_s3_bucket).and_return(true)
    allow(report).to receive(:bucket_name).and_return('my-test-bucket')
    allow(ReportMailer).to receive_message_chain(:tables_report, :deliver_now)
  end

  after {}

  describe '#perform' do
    it 'uploads the report to S3 and sends the email' do
      expect(report).to receive(:upload_to_s3).at_least(:once)
      expect(ReportMailer).to receive_message_chain(:tables_report, :deliver_now)
      report.perform(report_date)
    end

    it 'does not send an email when no addresses are configured' do
      allow(IdentityConfig.store).to receive(:irs_verification_report_config).and_return([])
      allow(IdentityConfig.store).to receive(:team_all_login_emails).and_return([])
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

  describe '#csv_file' do
    it 'generates valid CSV output' do
      csv_output = report.csv_file(dummy_report_data)
      expect(csv_output).to include('Header1,Header2')
      expect(csv_output).to include('Value1,Value2')
    end
  end
end
