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
      attachment_format: :xlsx,
      reports: [
        Reporting::EmailableReport.new(
          title: 'February 2021 Active Users',
          table: [
            ['Monthly Active Users', 'Value'],
            ['IAL1', 1],
            ['IDV', 1],
            ['Total', 2],
          ],
        ),
        Reporting::EmailableReport.new(
          title: 'Total user count (all-time)',
          table: [
            ['All-time user count'],
            [2289411],
          ],
        ),
        Reporting::EmailableReport.new(
          title: 'Account deletion rate (last 30 days)',
          float_as_percent: true,
          precision: 4,
          table: [
            ['Deleted Users',	'Total Users', 'Deletion Rate'],
            [137, 7434, 0.18429222],
          ],
        ),
        Reporting::EmailableReport.new(
          title: 'IDV app reuse rate Feb-2021',
          float_as_percent: true,
          precision: 4,
          table: [
            ['Num. SPs', 'Num. users', 'Percentage'],
            [2, 207422, 0.105164],
            [3, 6700, 0.003397],
            [4, 254, 0.000129],
            [5, 26, 0.000013],
            [6, 1, 0.000001],
            ['Total (all >1)', 214403, 0.108703],
          ],
        ),
        Reporting::EmailableReport.new(
          title: 'Total proofed identities',
          table: [
            ['Total proofed identities (Feb-2021)'],
            [1972368],
          ],
        ),
        Reporting::EmailableReport.new(
          title: 'Document upload proofing rates',
          float_as_percent: true,
          precision: 4,
          table: [
            ['metric', 'num_users', 'percent'],
            ['image_submitted', 5, 5.0 / 5],
            ['verified', 2, 2.0 / 5],
            ['not_verified_started_gpo', 1, 1.0 / 5],
            ['not_verified_started_in_person', 1, 1.0 / 5],
            ['not_verified_started_fraud_review', 1, 1.0 / 5],
          ],
        ),
      ],
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
end
