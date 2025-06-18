require 'rails_helper'

RSpec.describe Reports::IrsCredentialTenureReport do
  let(:report_date) { Date.new(2025, 5, 31) }
  let(:email) { 'irs.partner@example.com' }
  let(:emails) { [email] }
  let(:issuers) { ['urn:gov:gsa:openidconnect.profiles:sp:sso:irs:sample'] }
  let(:reports) do
    [
      Reporting::EmailableReport.new(
        title: 'Definitions',
        table: [['Metric', 'Definition'],
                ['Credential Tenure', 'The average age, in months, of all accounts.']],
        filename: 'definitions.csv',
      ),
      Reporting::EmailableReport.new(
        title: 'Overview',
        table: [['Report Timeframe', '2025-05-01 00:00:00 UTC to 2025-05-31 23:59:59 UTC'],
                ['Report Generated', '2025-06-01'], ['Issuer', issuers.first]],
        filename: 'overview.csv',
      ),
      Reporting::EmailableReport.new(
        title: 'IRS Credential Tenure Metric',
        table: [['Metric', 'Value'], ['Total Users', '10'], ['Credential Tenure', '24.5']],
        filename: 'metric.csv',
      ),
    ]
  end

  let(:tenure_report) do
    double(
      irs_credential_tenure_definition: reports[0],
      irs_credential_tenure_overview: reports[1],
      credential_tenure_emailable_report: reports[2],
      as_emailable_reports: reports,
    )
  end

  before do
    allow(IdentityConfig.store).to receive(:s3_reports_enabled).and_return(true)
    allow(IdentityConfig.store).to receive(:irs_credential_tenure_report_config).and_return(emails)
    allow(IdentityConfig.store).to receive(:irs_credential_tenure_report_issuers)
      .and_return(issuers)
    allow(ReportMailer).to receive(:tables_report).and_call_original
    allow_any_instance_of(described_class).to receive(:upload_to_s3)
    allow(Reporting::IrsCredentialTenureReport).to receive(:new).and_return(tenure_report)
  end

  describe '#perform' do
    it 'uploads each report to S3 and sends an email' do
      expect_any_instance_of(described_class).to receive(:upload_to_s3).exactly(3).times
      expect(ReportMailer).to receive(:tables_report).with(
        email: emails,
        subject: "IRS Credential Tenure Report - #{report_date}",
        reports: reports,
        message: kind_of(String),
        attachment_format: :csv,
      ).and_call_original

      subject.perform(report_date)
    end

    it 'does not send email if no email addresses are present' do
      allow(IdentityConfig.store).to receive(:irs_credential_tenure_report_config).and_return([])
      expect(ReportMailer).not_to receive(:tables_report)
      expect(subject.perform(report_date)).to eq(false)
    end
  end

  describe '#preamble' do
    it 'includes the environment and explainer link' do
      html = subject.preamble(env: 'test')
      expect(html).to include('Monthly Key Metrics Report Explainer document')
      expect(html).to include('test')
    end
  end

  describe '#emails' do
    it 'returns the configured emails' do
      expect(subject.emails).to eq(emails)
    end
  end

  describe '#issuers' do
    it 'returns the configured issuers' do
      expect(subject.issuers).to eq(issuers)
    end
  end

  describe '#csv_file' do
    it 'generates CSV from an array' do
      array = [['a', 'b'], [1, 2]]
      csv = subject.csv_file(array)
      expect(csv).to include('a,b')
      expect(csv).to include('1,2')
    end
  end
end
