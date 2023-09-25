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
      month: 'February 2021',
      csv_report: [
        [
          { title: 'IDV app reuse rate Feb-2021', float_as_percent: true, precision: 4 },
          ['Num. SPs', 'Num. users', 'Percentage'],
          [2, 207422, 0.105164],
          [3, 6700, 0.003397],
          [4, 254, 0.000129],
          [5, 26, 0.000013],
          [6, 1, 0.000001],
          ['Total (all >1)', 214403, 0.108703],
        ],
        [
          { title: 'Total proofed identities' },
          ['Total proofed identities (Feb-2021)'],
          [1972368]
        ],
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
