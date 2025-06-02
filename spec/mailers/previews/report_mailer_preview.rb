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
      email: 'email@example.com',
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
      email: 'test@example.com',
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
      email: 'test@example.com',
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
      email: 'test@example.com',
      subject: "Example Fraud Key Metrics Report - #{Time.zone.now.to_date}",
      message: fraud_metrics_report.preamble,
      attachment_format: :xlsx,
      reports: fraud_metrics_report.reports,
    )
  end

  def irs_authentication_report
    irs_authentication_report = Reports::IrsAuthenticationReport.new(Time.zone.yesterday)

    stub_cloudwatch_client(irs_authentication_report.irs_authentication_report)

    ReportMailer.tables_report(
      email: 'test@example.com',
      subject: "Example IRS Authentication Report - #{Time.zone.now.to_date}",
      message: irs_authentication_report.preamble,
      attachment_format: :csv,
      reports: irs_authentication_report.reports,
    )
  end

  def irs_fraud_metrics_report
    irs_fraud_metrics_report = Reports::IrsFraudMetricsReport.new(Time.zone.yesterday)

    stub_cloudwatch_client(irs_fraud_metrics_report.irs_fraud_metrics_lg99_report)

    ReportMailer.tables_report(
      email: 'test@example.com',
      subject: "Example IRS Fraud Key Metrics Report - #{Time.zone.now.to_date}",
      message: irs_fraud_metrics_report.preamble,
      attachment_format: :csv,
      reports: irs_fraud_metrics_report.reports,
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
      email: 'test@example.com',
      subject: "API Transaction Count Report - #{Time.zone.now.to_date}",
      message: api_transaction_count_report.preamble,
      attachment_format: :csv,
      reports: api_transaction_count_report.reports,
    )
  end

  def irs_verification_report
    irs_verification_report = Reports::IrsVerificationReport.new(Time.zone.yesterday)

    stub_cloudwatch_client(irs_verification_report.irs_verification_report)

    ReportMailer.tables_report(
      email: 'test@example.com',
      subject: "Example IRS Verification Report - #{Time.zone.now.to_date}",
      message: "Report: IRS Verification Report -  #{Time.zone.now.to_date}",
      attachment_format: :csv,
      reports: irs_verification_report.reports,
    )
  end

  def monthly_irs_verification_report
    monthly_irs_verification_report = Reports::MonthlyIrsVerificationReport.new(Time.zone.yesterday)

    stub_cloudwatch_client(monthly_irs_verification_report.irs_verification_report)

    ReportMailer.tables_report(
      email: 'test@example.com',
      subject: "Example Monthly IRS Verification Report - #{Time.zone.now.to_date}",
      message: "Report: IRS Verification Report -  #{Time.zone.now.to_date}",
      attachment_format: :csv,
      reports: monthly_irs_verification_report.reports,
    )
  end

  def irs_monthly_credentials_report
    report_date = Time.zone.yesterday
    report = Reports::IrsMonthlyCredMetricsReport.new(report_date)

    # Build emailable report
    emailable_report = report.as_emailable_irs_report(
      iaas: IaaReportingHelper.iaas,
      partner_accounts: IaaReportingHelper.partner_accounts,
      date: report_date,
      issuers: ['test-sp-1', 'test-sp-2'],
    )

    ReportMailer.tables_report(
      email: 'test@example.com',
      subject: "Example Credentials Report - #{Time.zone.now.to_date}",
      message: report.preamble,
      reports: emailable_report,
      attachment_format: :csv,
    )
  end

  def tables_report
    ReportMailer.tables_report(
      email: 'test@example.com',
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
