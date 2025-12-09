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
      "#{report_folder}/multi_issuer_monthly_cred_metrics.csv",
      "#{report_folder}/partner_monthly_cred_metrics.csv",
      "#{report_folder}/partner_monthly_cred_overview.csv",
      "#{report_folder}/partner_monthly_cred_definitions.csv",
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
  let(:mock_partner) { ['Partner_1'] }
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
      .and_return(mock_partner)
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

    # Mock the report data methods
    allow_any_instance_of(Reports::IrsMonthlyCredMetricsReport)
      .to receive(:issuer_report_data)
      .and_return([
                    ['Issuer', 'Monthly active users', 'Credentials authorized', 'New credentials',
                     'Existing credentials', 'Total auths'],
                    ['Issuer_4', 100, 50, 30, 20, 200],
                  ])

    allow_any_instance_of(Reports::IrsMonthlyCredMetricsReport)
      .to receive(:partner_report_data)
      .and_return([
                    ['Partner', 'Credentials authorized', 'New credentials',
                     'Existing credentials'],
                    ['Partner_1', 50, 30, 20],
                  ])

    # Mock the return from the invoice report
    allow_any_instance_of(Reports::IrsMonthlyCredMetricsReport)
      .to receive(:invoice_report_data)
      .and_return(fixture_csv_data)
  end

  context 'for begining of the month sends out the report to the internal and partner' do
    let(:report_date) { Date.new(2021, 3, 1).prev_day }
    subject(:report) { described_class.new(report_date, :both) }

    it 'sends out a report to team_data and PARTNER' do
      expect(ReportMailer).to receive(:tables_report).once.with(
        email: mock_reports_partner_emails,
        bcc: mock_reports_internal_emails,
        subject: "#{mock_partner.first} Monthly Credential Metrics - #{report_date.to_date}",
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

    it 'sends out a report to internal receivers' do
      expect(ReportMailer).to receive(:tables_report).once.with(
        email: mock_reports_internal_emails,
        bcc: [],
        subject: "#{mock_partner.first} Monthly Credential Metrics - #{report_date}",
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
        name: mock_partner,
        description: 'This is a description.',
        requesting_agency: mock_partner,
      )
    end

    let(:report_date) { Date.new(2025, 9, 30).in_time_zone('UTC').end_of_day }

    # Check that report values match expectations from csv fixture
    # Report should only return values for September 2025 (second row in csv)

    let(:parsed_invoice_data) { CSV.parse(fixture_csv_data, headers: true) }
    let(:report_year_month) { report_date.strftime('%Y%m') }

    before do
      # Override the mocks from the outer before block to use real data
      allow_any_instance_of(Reports::IrsMonthlyCredMetricsReport)
        .to receive(:issuer_report_data)
        .and_call_original

      allow_any_instance_of(Reports::IrsMonthlyCredMetricsReport)
        .to receive(:partner_report_data)
        .and_call_original
    end

    describe 'table sizes' do
      let(:mock_issuers) { ['Issuer_2', 'Issuer_3', 'Issuer_4'] }
      let(:issuer_count) { mock_issuers.count }
      let(:issuer_table) { result[0] }
      let(:partner_table) { result[1] }
      let(:result) { report.perform(report_date) }

      # Get all rows for the specified issuers and year_month
      let(:multi_issuer_yearmonth_data) do
        parsed_invoice_data.select do |r|
          mock_issuers.include?(r['issuer']) && r['year_month'] == report_year_month
        end.map { |row| row.to_h }
      end

      before do
        allow(IdentityConfig.store).to receive(:irs_issuers)
          .and_return(mock_issuers)
      end

      it 'has the correct table sizes' do
        # Check Report Tables Shape
        # One Issuer Table and One Partner Table
        expect(result.length).to eq(2)

        # Issuer table
        # One Header Column + 5 Data Columns"
        # One row per issuer

        aggregate_failures 'issuer table dimensions' do
          expect(issuer_table.length).to eq(1 + issuer_count)
          issuer_table.each_with_index do |row, idx|
            expect(row.length).to eq(6), "Row #{idx} should have 6 columns"
          end
        end

        # Check Partner Report Table Shape
        # One Header Column + 3 Data Columns"

        aggregate_failures 'partner table dimensions' do
          expect(partner_table.length).to eq(4)
          partner_table.each_with_index do |row, idx|
            expect(row.length).to eq(2), "Row #{idx} should have 2 columns"
          end
        end
      end

      it 'checks issuer-level counts for multiple issuers' do
        issuer_table_header = issuer_table.first

        issuer_table_data = issuer_table[1..]

        hashed_issuer_table = issuer_table_data.map do |row|
          issuer_table_header.zip(row).to_h
        end

        aggregate_failures 'multiple issuer values' do
          mock_issuers.each do |issuer|
            fixture_values = multi_issuer_yearmonth_data.find do |issuer_data|
              issuer == issuer_data['issuer']
            end

            report_values = hashed_issuer_table.find do |issuer_data|
              issuer == issuer_data['Issuer']
            end

            expected_monthly_active_users = fixture_values['issuer_unique_users'].to_i
            expected_new_ial_year1 =
              fixture_values['issuer_ial2_new_unique_user_events_year1_upfront'].to_i

            expected_existing_credentials_authorized =
              (fixture_values['issuer_ial2_new_unique_user_events_year1_existing'].to_i +
              fixture_values['issuer_ial2_new_unique_user_events_year2'].to_i +
              fixture_values['issuer_ial2_new_unique_user_events_year3'].to_i +
              fixture_values['issuer_ial2_new_unique_user_events_year4'].to_i +
              fixture_values['issuer_ial2_new_unique_user_events_year5'].to_i)

            # Issuer Credentials authorized
            expected_credentials_authorized = expected_new_ial_year1 +
                                              expected_existing_credentials_authorized

            # Total Auths
            expected_total_auths = fixture_values['issuer_ial1_plus_2_total_auth_count'].to_i

            # Test the processed data
            # rubocop:disable Layout/LineLength
            expect(report_values['Monthly active users']).to eq(expected_monthly_active_users)
            expect(report_values['Credentials authorized']).to eq(expected_credentials_authorized)
            expect(report_values['New identity verification credentials authorized']).to eq(expected_new_ial_year1)
            expect(report_values['Existing identity verification credentials authorized']).to eq(expected_existing_credentials_authorized)
            expect(report_values['Total authentications']).to eq(expected_total_auths)
            # rubocop:enable Layout/LineLength
          end
        end
      end

      it 'checks partner-level counts for a single partner' do
        report_values = partner_table[1..].to_h

        fixture_values = multi_issuer_yearmonth_data.find do |partner_data|
          mock_partner.include?(partner_data['partner'])
        end
        # rubocop:disable Layout/LineLength

        expected_new_ial_year1 = fixture_values['partner_ial2_new_unique_user_events_year1_upfront'].to_i

        expected_existing_credentials_authorized =
          %w[
            partner_ial2_new_unique_user_events_year1_existing
            partner_ial2_new_unique_user_events_year2
            partner_ial2_new_unique_user_events_year3
            partner_ial2_new_unique_user_events_year4
            partner_ial2_new_unique_user_events_year5
          ].sum { |key| fixture_values[key].to_i }
        # Partner Credentials authorized
        expected_credentials_authorized = expected_new_ial_year1 +
                                          expected_existing_credentials_authorized

        expect(report_values['Credentials authorized']).to eq(expected_credentials_authorized)
        expect(report_values['New identity verification credentials authorized']).to eq(expected_new_ial_year1)
        expect(report_values['Existing identity verification credentials authorized']).to eq(expected_existing_credentials_authorized)
        # rubocop:enable Layout/LineLength
      end
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
