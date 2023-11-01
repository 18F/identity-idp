class ReportMailerPreview < ActionMailer::Preview
  def warn_error
    ReportMailer.warn_error(
      email: 'test@example.com',
      error: ServiceProviderSeeder::ExtraServiceProviderError.new(
        'Extra service providers found in DB: a, b, c',
      ),
    )
  end

  def monthly_key_metrics_report
    monthly_key_metrics_report = Reports::MonthlyKeyMetricsReport.new(Time.zone.today)

    stub_cloudwatch_client(monthly_key_metrics_report.proofing_rate_report)
    stub_cloudwatch_client(monthly_key_metrics_report.monthly_proofing_report)

    ReportMailer.tables_report(
      email: 'test@example.com',
      subject: 'Example Key Metrics Report',
      message: monthly_key_metrics_report.preamble,
      attachment_format: :xlsx,
      reports: monthly_key_metrics_report.reports,
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
