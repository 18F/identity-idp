require 'rails_helper'

RSpec.describe Reports::IrsVerificationReport do
  let(:report_date) { Time.zone.today.end_of_day }
  let(:report) { described_class.new(report_date) }
  let(:dummy_report_data) { [['Header1', 'Header2'], ['Value1', 'Value2']] }
  let(:mock_report_object) do
    instance_double(
      Reporting::IrsVerificationReport, as_emailable_reports: [
        Struct.new(:table, :filename).new(dummy_report_data, 'dummy.csv'),
      ]
    )
  end

  before do
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

  describe '#perform' do
    it 'uploads the report to S3 and sends the email' do
      expect(report).to receive(:upload_to_s3).at_least(:once)
      expect(ReportMailer).to receive_message_chain(:tables_report, :deliver_now)

      report.perform(report_date)
    end

    it 'does not send an email when no addresses are configured' do
      allow(IdentityConfig.store).to receive(:irs_verification_report_config).and_return([])

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
    it 'returns a 7-day range starting from last Sunday' do
      range = report.previous_week_range
      expect(range).to be_a(Range)
      expect(range.first).to be < range.last
      expect((range.last.to_date - range.first.to_date).to_i).to eq(6)
    end
  end
end
