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
    ReportMailer.monthly_key_metrics_report(
      name: 'monthly-key-metrics-report',
      email: 'test@example.com',
      month: 'September 2021',
      csv_report: [
        [{ title: 'IDV app reuse rate Feb-2021' },
         ['Num. SPs', 'Num. users', 'Percentage'],
         ['Total (all >1)', 0, 0]],
        [{ title: 'Total proofed identities' },
         ['Total proofed identities (Feb-2021)', 0]],
      ],
    )
  end

  def tables_report
    ReportMailer.tables_report(
      email: 'test@example.com',
      subject: 'Example Report',
      tables: [
        [
          ['Some', 'String'],
          ['a', 'b'],
          ['c', 'd'],
        ],
        [
          { float_as_percent: true },
          [nil, 'Int', 'Float as Percent'],
          ['Row 1', 1, 0.5],
          ['Row 2', 1, 1.5],
        ],
        [
          { float_as_percent: false },
          [nil, 'Gigantic Int', 'Float as Float'],
          ['Row 1', 100_000_000, 1.0],
          ['Row 2', 123_456_789, 1.5],
        ],
      ],
    )
  end
end
