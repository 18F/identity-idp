class ReportMailerPreview < ActionMailer::Preview
  def warn_error
    ReportMailer.warn_error(
      email: 'test@example.com',
      error: ServiceProviderSeeder::ExtraServiceProviderError.new(
        'Extra service providers found in DB: a, b, c',
      ),
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
          [nil, 'Int', 'Float as Float'],
          ['Row 1', 1, 1.0],
          ['Row 2', 1, 1.5],
        ],
      ],
    )
  end
end
