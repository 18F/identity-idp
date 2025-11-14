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

  let(:mock_reports_partner_emails) { ['mock_partner@example.com'] }
  let(:mock_reports_internal_emails) { ['mock_internal@example.com'] }
  let(:mock_issuers) { ['Issuer_4'] }
  let(:mock_partners) { ['Partner_1'] }
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
      .and_return(mock_reports_partner_emails)
    allow(IdentityConfig.store).to receive(:team_daily_reports_emails)
      .and_return(mock_reports_internal_emails)
    allow(IdentityConfig.store).to receive(:irs_partner_strings)
      .and_return(mock_partners)
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
    # Add this at the end of your before block
    allow_any_instance_of(Reports::IrsMonthlyCredMetricsReport)
      .to receive(:invoice_report_data)
      .and_return(fixture_csv_data)
  end

  context 'for begining of the month sends out the report to the internal and partner' do
    let(:report_date) { Date.new(2021, 3, 1).prev_day }
    subject(:report) { described_class.new(report_date, :both) }

    it 'sends out a report to team_data and PARTNER' do
      expect(ReportMailer).to receive(:tables_report).once.with(
        email: ['mock_internal@example.com', 'mock_partner@example.com'],
        subject: 'IRS Monthly Credential Metrics - 2021-02-28',
        reports: anything,
        message: report.preamble,
        attachment_format: :csv,
      ).and_call_original

      report.perform(report_date, :both)
    end
  end

  context 'for any day of the month sends out the report to the internal' do
    let(:report_date) { Date.new(2021, 3, 15).prev_day }
    subject(:report) { described_class.new(report_date, :internal) }

    it 'sends out a report to team data' do
      expect(ReportMailer).to receive(:tables_report).once.with(
        email: ['mock_internal@example.com'],
        subject: 'IRS Monthly Credential Metrics - 2021-03-14',
        reports: anything,
        message: report.preamble,
        attachment_format: :csv,
      ).and_call_original

      report.perform(report_date, :internal)
    end
  end

  it 'does not send the report if no emails are configured' do
    allow(IdentityConfig.store).to receive(:irs_credentials_emails).and_return('')
    allow(IdentityConfig.store).to receive(:team_daily_reports_emails).and_return('')
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
        name: 'Partner_1',
        description: 'This is a description.',
        requesting_agency: 'Partner_1',
      )
    end

    let(:report_date) { Date.new(2025, 9, 30).in_time_zone('UTC').end_of_day }

    # Check that report values match expectations from csv fixture
    # Report should only return values for September 2025 (second row in csv)

    let(:parsed_invoice_data) { CSV.parse(fixture_csv_data, headers: true) }
    let(:report_year_month) { report_date.strftime('%Y%m') }

    let(:row) do
      (parsed_invoice_data.find do |r|
        r['issuer'] == mock_issuers.first && r['year_month'] == report_year_month
      end).to_h.transform_values(&:to_i)
    end

    it 'checks authentication counts in ial1 + ial2 & for single issuer' do
      result = report.perform(report_date)
      data_column =
        result.map do |row|
          row[1]
        end

      # Check Report Table Shape
      # Two Columns: "Metrics" and "Values"
      # One Header Row + 5 Data Rows"
      expect(result.transpose.length).to eq(2)
      expect(result.length).to eq(6)

      # Expected values
      expected_monthly_active_users = row['issuer_unique_users']

      expected_new_ial_year1 = row['issuer_ial2_new_unique_user_events_year1_upfront']

      expected_existing_credentials_authorized =
        row['issuer_ial2_new_unique_user_events_year1_existing'] +
        row['issuer_ial2_new_unique_user_events_year2'] +
        row['issuer_ial2_new_unique_user_events_year3'] +
        row['issuer_ial2_new_unique_user_events_year4'] +
        row['issuer_ial2_new_unique_user_events_year5']

      # Partner Credentials authorized
      expected_credentials_authorized = expected_new_ial_year1 +
                                        expected_existing_credentials_authorized

      # Total Auths
      expected_total_auths = row['issuer_ial1_plus_2_total_auth_count']

      # Test the processed data
      expect(data_column[0]).to eq('Value') # Column label
      expect(data_column[1]).to eq(expected_monthly_active_users)
      expect(data_column[2]).to eq(expected_credentials_authorized)
      expect(data_column[3]).to eq(expected_new_ial_year1)
      expect(data_column[4]).to eq(expected_existing_credentials_authorized)
      expect(data_column[5]).to eq(expected_total_auths)
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
