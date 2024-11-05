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
    def fetch(**)
      []
    end
  end

  def stub_cloudwatch_client(report)
    class << report
      def cloudwatch_client
        FakeCloudwatchClient.new
      end
    end
  end
end
