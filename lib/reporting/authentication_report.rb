module Reporting
  class AuthenticationReport
    def initialize()

    def report_body
      CSV.generate do |csv|
        csv << [
          'Metric',
          'Number of accounts (cumulative)',
          '%% of total from start',
        ]

        csv << [
          'New Users Started IAL1 Verification',
        ]

        csv << [
          'New Users Completed IAL1 Password Setup',
        ]

        csv << [
          'New Users Completed IAL1 MFA',
        ]

        csv << [
          'New IAL1 Users Consented to IRS Access'
        ]
      end
    end

    def logs
      Reporting::CloudwatchQuery.new(
        events: [
          'User Registration: Email Confirmation',
          'User Registration: 2FA Setup visited',
          'User Registration: User Fully Registered',
          'SP redirect initiated',
        ],
        service_provider: service_provider,
      )
    end
  end
end
