class ReportMailerPreview < ActionMailer::Preview
  def deleted_user_accounts_report
    data = <<~CSV
      2023-01-01T:00:00:00Z,00000000-0000-0000-0000-000000000000
    CSV

    ReportMailer.deleted_user_accounts_report(
      email: 'test@example.com',
      name: 'Example Partner',
      issuers: ['test-sp-1', 'test-sp-2'],
      data:,
    )
  end

  def warn_error
    ReportMailer.warn_error(
      email: 'test@example.com',
      error: ServiceProviderSeeder::ExtraServiceProviderError.new(
        'Extra service providers found in DB: a, b, c',
      ),
    )
  end

  def ab_tests_report
    report = Reports::AbTestsReport.new(Time.zone.now).ab_tests_report(
      AbTest.new(
        experiment_name: 'reCAPTCHA at Sign-In',
        persist: true,
        max_participants: 10_000,
        report: {
          email: 'email@example.com',
          queries: [
            {
              title: 'Sign in success rate by CAPTCHA validation performed',
              query: <<~QUERY,
                fields properties.event_properties.captcha_validation_performed as `Captcha Validation Performed`
                | filter name = 'Email and Password Authentication'
                | stats avg(properties.event_properties.success)*100 as `Success Percent` by `Captcha Validation Performed`
                | sort `Captcha Validation Performed` asc
              QUERY
              row_labels: ['Validation Not Performed', 'Validation Performed'],
            },
          ],
        },
      ),
    )

    stub_cloudwatch_client(
      report,
      data: [
        { 'Captcha Validation Performed' => '0', 'Success Percent' => '90.18501' },
        { 'Captcha Validation Performed' => '1', 'Success Percent' => '85.68103' },
      ],
    )

    ReportMailer.tables_report(
      to: 'email@example.com',
      subject: "A/B Tests Report - reCAPTCHA at Sign-In - #{Time.zone.now.to_date}",
      message: [
        "A/B Tests Report - reCAPTCHA at Sign-In - #{Time.zone.now.to_date}",
        report.participants_message,
      ].compact,
      reports: report.as_emailable_reports,
      attachment_format: :csv,
    )
  end

  def monthly_key_metrics_report
    monthly_key_metrics_report = Reports::MonthlyKeyMetricsReport.new(Time.zone.yesterday)

    stub_cloudwatch_client(monthly_key_metrics_report.proofing_rate_report)
    stub_cloudwatch_client(monthly_key_metrics_report.monthly_idv_report)

    ReportMailer.tables_report(
      to: 'test@example.com',
      subject: "Example Key Metrics Report - #{Time.zone.now.to_date}",
      message: monthly_key_metrics_report.preamble,
      attachment_format: :xlsx,
      reports: monthly_key_metrics_report.reports,
    )
  end

  def protocols_report
    date = Time.zone.yesterday
    report = Reports::ProtocolsReport.new.tap { |r| r.report_date = date }

    stub_cloudwatch_client(report.send(:report))

    ReportMailer.tables_report(
      to: 'test@example.com',
      subject: "Weekly Protocols Report - #{date}",
      message: "Report: protocols-report #{date}",
      attachment_format: :csv,
      reports: report.send(:weekly_protocols_emailable_reports),
    )
  end

  def fraud_metrics_report
    fraud_metrics_report = Reports::FraudMetricsReport.new(Time.zone.yesterday)

    stub_cloudwatch_client(fraud_metrics_report.fraud_metrics_lg99_report)

    ReportMailer.tables_report(
      to: 'test@example.com',
      subject: "Example Fraud Key Metrics Report - #{Time.zone.now.to_date}",
      message: fraud_metrics_report.preamble,
      attachment_format: :xlsx,
      reports: fraud_metrics_report.reports,
    )
  end

  def identity_verification_outcomes_report
    identity_verification_outcomes_report = Reports::IdentityVerificationOutcomesReport.new(
      Time.zone.yesterday,
    )

    stub_cloudwatch_client(
      identity_verification_outcomes_report.identity_verification_outcomes_report,
    )

    ReportMailer.tables_report(
      to: 'test@example.com',
      subject: "Example Identity Verification Outcomes Report - #{Time.zone.now.to_date}",
      message: identity_verification_outcomes_report.preamble,
      attachment_format: :csv,
      reports: identity_verification_outcomes_report.reports,
    )
  end

  def sp_registration_funnel_report
    require 'reporting/irs_registration_funnel_report'

    mock_issuers = ['test_issuer']
    mock_agency = 'Test_agency'
    date    = Time.zone.yesterday.end_of_day

    builder = Reporting::IrsRegistrationFunnelReport.new(
      issuers: mock_issuers,
      time_range: date.beginning_of_week(:sunday).prev_occurring(:sunday).all_week(:sunday),
      agency_abbreviation: mock_agency,
    )
    stub_cloudwatch_client(builder)

    ReportMailer.tables_report(
      to: 'test@example.com',
      bcc: 'bcc@example.com',
      subject: "Example #{mock_agency} Registration Funnel Report - #{Time.zone.now.to_date}",
      message: "Report: #{mock_agency} Registration Funnel Report - #{date.to_date}",
      attachment_format: :csv,
      reports: builder.as_emailable_reports,
    )
  end

  def sp_fraud_metrics_report
    require 'reporting/irs_fraud_metrics_lg99_report'

    date    = Time.zone.yesterday.end_of_day
    issuers = ['issuer1']
    agency  = 'Test_Agency'

    builder = Reporting::IrsFraudMetricsLg99Report.new(
      time_range: date.all_month,
      issuers: issuers,
      agency_abbreviation: agency,
    )

    stub_cloudwatch_client(builder)

    ReportMailer.tables_report(
      to: 'test@example.com',
      bcc: 'bcc@example.com',
      subject: "#{agency} Fraud Metric Report - #{date.to_date}",
      message: "Report: #{agency} Fraud Metric Report - #{date.to_date}",
      attachment_format: :csv,
      reports: builder.as_emailable_reports,
    )
  end

  def api_transaction_count_report
    api_transaction_count_report = Reports::ApiTransactionCountReport.new(Time.zone.yesterday)

    data = [
      ['UUID', 'trans', 'vendor'],
      [1111, 'b', 'instantVeryfy'],
      [2222, 'd', 'idv'],
    ]

    stub_cloudwatch_client(api_transaction_count_report.api_transaction_count_report, data: data)

    ReportMailer.tables_report(
      to: 'test@example.com',
      subject: "API Transaction Count Report - #{Time.zone.now.to_date}",
      message: api_transaction_count_report.preamble,
      attachment_format: :csv,
      reports: api_transaction_count_report.reports,
    )
  end

  def sp_verification_report
    require 'reporting/irs_verification_report'

    date    = Time.zone.yesterday.end_of_day
    issuers = ['issuer1']
    agency  = 'Test_Agency'

    builder = Reporting::IrsVerificationReport.new(
      time_range: date.beginning_of_week(:sunday).prev_occurring(:sunday).all_week(:sunday),
      issuers: issuers,
      agency_abbreviation: agency,
    )
    stub_cloudwatch_client(builder)

    ReportMailer.tables_report(
      to: 'test@example.com',
      bcc: 'bcc@example.com',
      subject: "#{agency} Verification Report - #{date.to_date}",
      message: "Report: #{agency} Verification Report - #{date.to_date}",
      attachment_format: :csv,
      reports: builder.as_emailable_reports,
    )
  end

  def sp_verification_demographics_report
    require 'reporting/irs_verification_demographics_report'

    mock_issuers = ['test_issuer']
    mock_agency = 'Test_agency'
    date    = Time.zone.yesterday.end_of_day

    builder = Reporting::IrsVerificationDemographicsReport.new(
      issuers: mock_issuers,
      time_range: date.beginning_of_week(:sunday).prev_occurring(:sunday).all_week(:sunday),
      agency_abbreviation: mock_agency,
    )
    stub_cloudwatch_client(builder)

    ReportMailer.tables_report(
      to: 'test@example.com',
      bcc: 'bcc@example.com',
      subject: "Example #{mock_agency} Verification Demographics Report - #{Time.zone.now.to_date}",
      message: "Report: #{mock_agency} Verification Demographics Report - #{date.to_date}",
      attachment_format: :csv,
      reports: builder.as_emailable_reports,
    )
  end

  def irs_credential_tenure_report
    irs_credential_tenure_report = Reports::IrsCredentialTenureReport.new(Time.zone.yesterday)

    ReportMailer.tables_report(
      to: 'test@example.com',
      subject: "Example IRS Credential Tenure Report - #{Time.zone.now.to_date}",
      message: "Report: IRS Credentual Tenure Report -  #{Time.zone.now.to_date}",
      attachment_format: :csv,
      reports: irs_credential_tenure_report.reports,
    )
  end

  def monthly_sp_verification_report
    require 'reporting/irs_verification_report'

    date    = Time.zone.yesterday.end_of_day
    issuers = ['issuer1']
    agency  = 'Test_Agency'

    builder = Reporting::IrsVerificationReport.new(
      time_range: date.all_month,
      issuers: issuers,
      agency_abbreviation: agency,
    )

    stub_cloudwatch_client(builder)

    ReportMailer.tables_report(
      to: 'test@example.com',
      bcc: 'bcc@example.com',
      subject: "#{agency} Verification Report - #{date.to_date}",
      message: "Report: #{agency} Verification Report - #{date.to_date}",
      attachment_format: :csv,
      reports: builder.as_emailable_reports,
    )
  end

  def sp_monthly_credentials_report
    report_date = Time.zone.parse('2025-11-30').end_of_day
    config = {
      'issuers' => ['Issuer_2', 'Issuer_3', 'Issuer_4'],
      'partner_strings' => ['Partner_1'],
      'partner_emails' => ['partner1@example.com'],
      'internal_emails' => ['internal1@example.com'],
    }

    report = Reports::IrsMonthlyCredMetricsReport.new(report_date, :internal)

    # Apply config the same way send_report does
    report.instance_variable_set(:@report_date, report_date)
    report.instance_variable_set(:@report_receiver, :internal)
    report.instance_variable_set(:@issuers, config['issuers'])
    report.instance_variable_set(:@partner_strings, config['partner_strings'])
    report.instance_variable_set(:@partner_emails, config['partner_emails'])
    report.instance_variable_set(:@internal_emails, config['internal_emails'])
    report.instance_variable_set(
      :@report_name,
      "#{config['partner_strings'].first.downcase}_monthly_cred_metrics",
    )

    fixture_csv_data = File.read(
      Rails.root.join('spec', 'fixtures', 'partner_cred_metrics_input.csv'),
    )

    report.define_singleton_method(:invoice_report_data) { fixture_csv_data }

    emailable_reports = report.as_emailable_partner_report(date: report_date)

    ReportMailer.tables_report(
      to: 'test@example.com',
      subject: "Example Partner Monthly Credential Metrics - #{report_date.to_date}",
      message: report.preamble,
      reports: emailable_reports,
      attachment_format: :csv,
    )
  end

  def tables_report
    ReportMailer.tables_report(
      to: 'test@example.com',
      subject: 'Example Report',
      message: 'Sample Message',
      attachment_format: :csv,
      reports: [
        Reporting::EmailableReport.new(
          table: [
            ['Some', 'String'],
            ['a', 'b'],
            ['c', 'd'],
          ],
        ),
        Reporting::EmailableReport.new(
          float_as_percent: true,
          table: [
            [nil, 'Int', 'Float as Percent'],
            ['Row 1', 1, 0.5],
            ['Row 2', 1, 1.5],
          ],
        ),
        Reporting::EmailableReport.new(
          float_as_percent: false,
          table: [
            [nil, 'Gigantic Int', 'Float as Float'],
            ['Row 1', 100_000_000, 1.0],
            ['Row 2', 123_456_789, 1.5],
          ],
        ),
      ],
    )
  end

  private

  class FakeCloudwatchClient
    def initialize(data:)
      @data = data
    end

    def fetch(**)
      @data
    end
  end

  def stub_cloudwatch_client(report, data: [])
    class << report
      attr_accessor :_stubbed_cloudwatch_data

      def cloudwatch_client
        FakeCloudwatchClient.new(data: @_stubbed_cloudwatch_data)
      end
    end
    report._stubbed_cloudwatch_data = data
    report
  end
end
