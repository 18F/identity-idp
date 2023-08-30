namespace :report do
  task failure_rate: :environment do
    require 'reporting/identity_verification_report'

    report = Reporting::IdentityVerificationReport.new(
      issuer: nil,
      time_range: 90.days.ago.beginning_of_day..1.day.ago.end_of_day,
      progress: true,
    )
    warn report.to_csv
  end
end
