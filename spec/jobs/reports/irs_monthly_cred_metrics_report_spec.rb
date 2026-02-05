require 'rails_helper'

RSpec.describe Reports::IrsMonthlyCredMetricsReport do
  let(:report_date) { Date.new(2021, 3, 2).in_time_zone('UTC').end_of_day }
  let(:report_receiver) { :internal }
  subject(:report)      { Reports::IrsMonthlyCredMetricsReport.new(report_date, report_receiver) }

  let(:s3_report_bucket_prefix) { 'reports-bucket' }

  let(:mock_reports_partner_emails)  { ['mock_partner@example.com'] }
  let(:mock_reports_internal_emails) { ['mock_internal@example.com'] }
  let(:mock_issuers) { ['Issuer_4'] }
  let(:mock_partner_strings) { ['Partner_1'] }

  let(:report_config) do
    {
      'issuers' => mock_issuers,
      'partner_strings' => mock_partner_strings,
      'partner_emails' => mock_reports_partner_emails,
      'internal_emails' => mock_reports_internal_emails,
    }
  end

  # Derived by job: "#{partner_strings.first.downcase}_monthly_cred_metrics"
  let(:report_name) { "#{mock_partner_strings.first.downcase}_monthly_cred_metrics" }

  let(:report_folder) do
    "int/#{report_name}/2021/2021-03-02.#{report_name}"
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

  let(:fixture_csv_data) do
    fixture_path = Rails.root.join('spec', 'fixtures', 'partner_cred_metrics_input.csv')
    File.read(fixture_path)
  end

  before do
    # App config/environment
    allow(Identity::Hostdata).to receive(:env).and_return('int')
    allow(Identity::Hostdata).to receive(:aws_account_id).and_return('1234')
    allow(Identity::Hostdata).to receive(:aws_region).and_return('us-west-1')
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
      .and_return(
        [
          ['Issuer', 'Monthly active users', 'Credentials authorized',
           'New identity verification credentials authorized',
           'Existing identity verification credentials authorized',
           'Total authentications'],
          ['Issuer_4', 100, 50, 30, 20, 200],
        ],
      )

    allow_any_instance_of(Reports::IrsMonthlyCredMetricsReport)
      .to receive(:partner_report_data)
      .and_return(
        [
          ['Metric', 'Value'],
          ['Credentials authorized', 50],
          ['New identity verification credentials authorized', 30],
          ['Existing identity verification credentials authorized', 20],
        ],
      )

    # Invoice CSV used by original builders (only needed for fixture builder context)
    allow_any_instance_of(Reports::IrsMonthlyCredMetricsReport)
      .to receive(:invoice_report_data)
      .and_return(fixture_csv_data)

    allow(ReportMailer).to receive_message_chain(:tables_report, :deliver_now)
  end

  context 'for beginning of the month sends out the report to the internal and partner' do
    let(:report_receiver) { :both }
    let(:report_date) { Date.new(2021, 3, 1).prev_day } # 2021-02-28
    subject(:report) do
      Reports::IrsMonthlyCredMetricsReport.new(report_date, report_receiver, report_config)
    end

    it 'sends report to partner (to) and internal (bcc)' do
      expect(ReportMailer).to receive(:tables_report).once.with(
        to: mock_reports_partner_emails,
        bcc: mock_reports_internal_emails,
        subject:
          "#{mock_partner_strings.first} Monthly Credential Metrics - " \
          "#{report_date.to_date}",
        reports: anything,
        message: report.preamble,
        attachment_format: :csv,
      ).and_call_original

      report.perform(report_date, :both, report_config)
    end
  end

  context 'for any day of the month sends out the report to the internal' do
    let(:report_receiver) { :internal }
    let(:report_date) { Date.new(2021, 3, 15).prev_day } # 2021-03-14
    subject(:report) do
      Reports::IrsMonthlyCredMetricsReport.new(report_date, report_receiver, report_config)
    end

    it 'sends out a report to internal receivers' do
      expect(ReportMailer).to receive(:tables_report).once.with(
        to: mock_reports_internal_emails,
        bcc: [],
        subject:
          "#{mock_partner_strings.first} Monthly Credential Metrics - " \
          "#{report_date.to_date}",
        reports: anything,
        message: report.preamble,
        attachment_format: :csv,
      ).and_call_original

      report.perform(report_date, :internal, report_config)
    end
  end

  context 'recipient is both but partner emails are empty' do
    let(:report_receiver) { :both }
    let(:report_date) { Date.new(2021, 3, 1).prev_day } # 2021-02-28
    subject(:report) do
      Reports::IrsMonthlyCredMetricsReport.new(report_date, report_receiver, report_config)
    end

    let(:report_config) do
      super().merge(
        'partner_emails' => [],
        'internal_emails' => mock_reports_internal_emails,
      )
    end

    it 'logs a warning and sends the report only to internal emails' do
      expect(Rails.logger).to receive(:warn).with(
        "#{mock_partner_strings.first} Monthly Credential Report: recipient is :both " \
        "but no external email specified",
      )

      expect(ReportMailer).to receive(:tables_report).once.with(
        to: mock_reports_internal_emails,
        bcc: [],
        subject:
          "#{mock_partner_strings.first} Monthly Credential Metrics - " \
          "#{report_date.to_date}",
        reports: anything,
        message: report.preamble,
        attachment_format: :csv,
      ).and_call_original

      report.perform(report_date, :both, report_config)
    end
  end

  context 'recipient is internal but internal emails are empty' do
    let(:report_receiver) { :internal }
    let(:report_date) { Date.new(2021, 3, 15).prev_day } # 2021-03-14
    subject(:report) do
      Reports::IrsMonthlyCredMetricsReport.new(report_date, report_receiver, report_config)
    end

    let(:report_config) do
      super().merge(
        'internal_emails' => [],
        'partner_emails' => mock_reports_partner_emails,
      )
    end

    it 'logs a warning and does not send the report' do
      expect(Rails.logger).to receive(:warn).with(
        "No email addresses received - #{mock_partner_strings.first} " \
        "Monthly Credential Report NOT SENT",
      )

      expect(ReportMailer).not_to receive(:tables_report)
      expect(report).not_to receive(:as_emailable_partner_report)

      report.perform(report_date, :internal, report_config)
    end
  end

  it 'does not send the report if no emails are configured' do
    config = report_config.merge('partner_emails' => [], 'internal_emails' => [])

    expect(ReportMailer).not_to receive(:tables_report)
    expect(report).not_to receive(:as_emailable_partner_report)
    report.perform(report_date, :internal, config)
  end

  it 'uploads a file to S3 based on the report date' do
    expected_s3_paths.each do |path|
      expect(report).to receive(:upload_file_to_s3_bucket).with(
        path: path,
        **s3_metadata,
      ).once.and_call_original
    end

    report.perform(report_date, :internal, report_config)
  end

  describe '#preamble' do
    let(:env) { 'prod' }
    subject(:preamble) { report.preamble(env:) }

    it 'has a blank preamble in prod' do
      expect(preamble).to be_blank
    end

    context 'in a non-prod environment' do
      let(:env) { 'staging' }

      it 'is valid HTML and includes env name' do
        expect(preamble).to be_html_safe
        doc = Nokogiri::XML(preamble)
        alert = doc.at_css('.usa-alert')
        expect(alert.text).to include(env)
      end
    end
  end

  context 'with fixture data and original builders' do
    let(:report_date) { Date.new(2025, 9, 30).in_time_zone('UTC').end_of_day }

    # Check that report values match expectations from csv fixture
    # Report should only return values for September 2025 (second row in csv)

    let(:parsed_invoice_data) { CSV.parse(fixture_csv_data, headers: true) }
    let(:report_year_month) { report_date.strftime('%Y%m') }

    let(:report_config) do
      super().merge(
        'issuers' => ['Issuer_2', 'Issuer_3', 'Issuer_4'],
        'partner_strings' => mock_partner_strings,
      )
    end

    before do
      # Use real builder logic
      allow_any_instance_of(Reports::IrsMonthlyCredMetricsReport)
        .to receive(:issuer_report_data).and_call_original
      allow_any_instance_of(Reports::IrsMonthlyCredMetricsReport)
        .to receive(:partner_report_data).and_call_original
    end

    it 'returns issuer and partner tables with expected shapes and values' do
      result = report.perform(report_date, :internal, report_config)
      issuer_table, partner_table = result

      expect(result.length).to eq(2)

      expect(issuer_table.first.length).to eq(6)
      expect(issuer_table.length).to eq(1 + 3)

      expect(partner_table.length).to eq(4)
      partner_table.each { |row| expect(row.length).to eq(2) }

      fixture_row = parsed_invoice_data.find do |r|
        r['issuer'] == 'Issuer_4' && r['year_month'] == report_year_month
      end
      expect(fixture_row).to be_present

      header = issuer_table.first
      issuer_4_row = issuer_table[1..].find { |r| r[0] == 'Issuer_4' }
      hashed = header.zip(issuer_4_row).to_h

      expected_mau = fixture_row['issuer_unique_users'].to_i
      expected_new = fixture_row['issuer_ial2_new_unique_user_events_year1_upfront'].to_i
      expected_existing =
        %w[
          issuer_ial2_new_unique_user_events_year1_existing
          issuer_ial2_new_unique_user_events_year2
          issuer_ial2_new_unique_user_events_year3
          issuer_ial2_new_unique_user_events_year4
          issuer_ial2_new_unique_user_events_year5
        ].sum { |k| fixture_row[k].to_i }
      expected_total = fixture_row['issuer_ial1_plus_2_total_auth_count'].to_i

      expect(hashed['Monthly active users']).to eq(expected_mau)
      expect(hashed['Credentials authorized']).to eq(expected_new + expected_existing)
      expect(hashed['New identity verification credentials authorized']).to eq(expected_new)
      expect(hashed['Existing identity verification credentials authorized'])
        .to eq(expected_existing)
      expect(hashed['Total authentications']).to eq(expected_total)
    end
  end
end
