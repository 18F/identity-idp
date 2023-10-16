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
    ReportMailer.tables_report(
      email: 'test@example.com',
      subject: 'Example Key Metrics Report',
      message: 'Key Metrics Report February 2021',
      tables: [
        [
          { title: 'February 2021 Active Users' },
          ['Monthly Active Users', 'Value'],
          ['IAL1', 1],
          ['IDV', 1],
          ['Total', 2],
        ],
        [
          { title: 'Total user count (all-time)' },
          ['All-time user count'],
          [2289411],
        ],
        [
          { title: 'Account deletion rate (last 30 days)', float_as_percent: true, precision: 4 },
          ['Deleted Users',	'Total Users', 'Deletion Rate'],
          [137, 7434, 0.18429222],
        ],
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
          [1972368],
        ],
        [
          { title: 'Document upload proofing rates', float_as_percent: true, precision: 4 },
          ['metric', 'num_users', 'percent'],
          ['image_submitted', 5, 5.0 / 5],
          ['verified', 1, 1.0 / 5],
          ['not_verified_started_gpo', 1, 1.0 / 5],
          ['not_verified_started_in_person', 1, 1.0 / 5],
          ['not_verified_started_fraud_review', 1, 1.0 / 5],
        ],
      ],
    )
  end

  def tables_report
    ReportMailer.tables_report(
      email: 'test@example.com',
      subject: 'Example Report',
      message: 'Sample Message',
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
