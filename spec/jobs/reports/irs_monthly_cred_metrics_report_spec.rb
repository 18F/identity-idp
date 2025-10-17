require 'rails_helper'

RSpec.describe Reports::IrsMonthlyCredMetricsReport do
  let(:report_date) { Date.new(2021, 3, 2).in_time_zone('UTC').end_of_day }
  let(:report_receiver) { :internal }
  subject(:report) { Reports::IrsMonthlyCredMetricsReport.new(report_date, report_receiver) }

  let(:name) { 'irs_monthly_cred_metrics' }
  let(:s3_report_bucket_prefix) { 'reports-bucket' }
  let(:report_folder) do
    'int/irs_monthly_cred_metrics/2021/2021-03-02.irs_monthly_cred_metrics'
  end

  let(:expected_s3_paths) do
    [
      "#{report_folder}/irs_monthly_cred_metrics.csv",
      "#{report_folder}/irs_monthly_cred_overview.csv",
      "#{report_folder}/irs_monthly_cred_definitions.csv",
    ]
  end
  let(:s3_metadata) do
    {
      body: anything,
      content_type: 'text/csv',
    }
  end

  let(:mock_daily_reports_emails) { ['mock_partner@example.com'] }
  let(:mock_issuers) { ['urn:gov:gsa:openidconnect.profiles:sp:sso:agency_name:partner_app_name'] }
  let(:irs_partners) { ['PARTNER_NAME'] }
  let(:fixture_csv_data) do
    fixture_path = Rails.root.join('spec', 'fixtures', 'partner_cred_metrics_input.csv')
    File.read(fixture_path)
  end

  before do
    # App config/environment
    allow(Identity::Hostdata).to receive(:env).and_return('int')
    allow(Identity::Hostdata).to receive(:aws_account_id).and_return('1234')
    allow(Identity::Hostdata).to receive(:aws_region).and_return('us-west-1')
    allow(IdentityConfig.store).to receive(:irs_credentials_emails)
      .and_return(mock_daily_reports_emails)
    allow(IdentityConfig.store).to receive(:irs_partner_strings)
      .and_return(irs_partners)
    allow(IdentityConfig.store).to receive(:irs_issuers)
      .and_return(mock_issuers)
    allow(IdentityConfig.store).to receive(:s3_report_bucket_prefix)
      .and_return(s3_report_bucket_prefix)

    # S3 stub
    Aws.config[:s3] = {
      stub_responses: {
        put_object: {},
      },
    }
  end

  context 'for a report_date is the beginning of the month, it sends records for previous month' do
    let(:report_date) { Date.new(2021, 3, 1).prev_day }

    it 'sends out a report to PARTNER' do
      expect(ReportMailer).to receive(:tables_report).once.with(
        email: ['mock_partner@example.com'],
        subject: 'IRS Monthly Credential Metrics - 2021-02-28',
        reports: anything,
        message: report.preamble,
        attachment_format: :csv,
      ).and_call_original

      report.perform(report_date)
    end
  end

  it 'does not send the report if no emails are configured' do
    allow(IdentityConfig.store).to receive(:irs_credentials_emails).and_return('')
    expect(ReportMailer).not_to receive(:tables_report)
    expect(report).not_to receive(:reports)
    report.perform(report_date)
  end

  it 'uploads a file to S3 based on the report date' do
    expected_s3_paths.each do |path|
      expect(report).to receive(:upload_file_to_s3_bucket).with(
        path: path,
        **s3_metadata,
      ).exactly(1).time.and_call_original
    end

    report.perform(report_date)
  end

  describe '#preamble' do
    let(:env) { 'prod' }
    subject(:preamble) { report.preamble(env:) }

    context 'in a prod environment' do
      it 'has a blank preamble' do
        expect(preamble).to be_blank
      end
    end

    context 'in a non-prod environment' do
      let(:env) { 'staging' }
      subject(:preamble) { report.preamble(env:) }

      it 'is valid HTML' do
        expect(preamble).to be_html_safe
        expect { Nokogiri::XML(preamble) { |c| c.strict } }.not_to raise_error
      end

      it 'has an alert with the environment name' do
        expect(preamble).to be_html_safe
        doc = Nokogiri::XML(preamble)

        alert = doc.at_css('.usa-alert')
        expect(alert.text).to include(env)
      end
    end
  end

  context 'with data generates report' do
    let(:partner_account1) do
      create(
        :partner_account,
        id: 123,
        name: 'PARTNER_NAME',
        description: 'This is a description.',
        requesting_agency: 'PARTNER_NAME',
      )
    end

    let(:report_date) { Date.new(2021, 1, 31).in_time_zone('UTC').end_of_day }

    it 'checks authentication counts in ial1 + ial2 & checks partner single issuer cases' do
      allow(report).to receive(:invoice_report_data).and_return(fixture_csv_data)

      result = report.perform(report_date)
      data_column = result.map { |row| row[1] }
      expect(result.transpose.length).to eq(2) # Two Columns: "Metrics" and "Values"
      expect(result.length).to eq(6) # One Header Row + 6 Data Rows"

      # Test the processed data
      expect(data_column[0]).to eq('Value') # Values
      expect(data_column[1]).to eq(9817) # Monthly Active Users - iaa_unique_users
      expect(data_column[2]).to eq(95 + 53) # IAL2 Auths - partner_ial2_unique_user_events_year12345
      expect(data_column[3]).to eq(95) # New IAL Year 1 - partner_ial2_unique_user_events_year1
      expect(data_column[4]).to eq(53) # New IAL Year 2 - partner_ial2_unique_user_events_year2345
      expect(data_column[5]).to eq(20769) # Total Auths - issuer_ial1_plus_2_total_auth_count
    end
  end

  def build_iaa_order(order_number:, date_range:, iaa_gtc:)
    create(
      :iaa_order,
      order_number: order_number,
      start_date: date_range.begin,
      end_date: date_range.end,
      iaa_gtc: iaa_gtc,
    )
  end

  def build_integration(issuer:, partner_account:)
    create(
      :integration,
      issuer: issuer,
      partner_account: partner_account,
    )
  end

  def build_integration2(service_provider:, partner_account:)
    create(
      :integration,
      service_provider: service_provider,
      partner_account: partner_account,
    )
  end

  def create_sp_return_log(user:, issuer:, ial:, returned_at:)
    create(
      :sp_return_log,
      user_id: user.id,
      issuer: issuer,
      ial: ial,
      returned_at: returned_at,
      profile_verified_at: user.profiles.map(&:verified_at).max,
      billable: true,
    )
  end
end
