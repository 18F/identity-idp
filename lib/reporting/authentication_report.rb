# frozen_string_literal: true

require 'csv'
begin
  require 'reporting/cloudwatch_client'
  require 'reporting/cloudwatch_query_quoting'
  require 'reporting/command_line_options'
rescue LoadError => e
  warn 'could not load paths, try running with "bundle exec rails runner"'
  raise e
end

module Reporting
  class AuthenticationReport
    include Reporting::CloudwatchQueryQuoting

    attr_reader :issuer, :time_range

    module Events
      OIDC_AUTH_REQUEST = 'OpenID Connect: authorization request'
      EMAIL_CONFIRMATION = 'User Registration: Email Confirmation'
      TWO_FA_SETUP_VISITED = 'User Registration: 2FA Setup visited'
      USER_FULLY_REGISTERED = 'User Registration: User Fully Registered'
      SP_REDIRECT = 'SP redirect initiated'

      def self.all_events
        constants.map { |c| const_get(c) }
      end
    end

    # @param [String] isssuer
    # @param [Range<Time>] time_range
    def initialize(
      issuer:,
      time_range:,
      verbose: false,
      progress: false,
      slice: 3.hours,
      threads: 5
    )
      @issuer = issuer
      @time_range = time_range
      @verbose = verbose
      @progress = progress
      @slice = slice
      @threads = threads
    end

    def verbose?
      @verbose
    end

    def progress?
      @progress
    end

    # rubocop:disable Metrics/BlockLength
    def to_csv
      CSV.generate do |csv|
        csv << ['Report Timeframe', "#{time_range.begin} to #{time_range.end}"]
        csv << ['Report Generated', Date.today.to_s] # rubocop:disable Rails/Date
        csv << ['Issuer', issuer]
        csv << []
        csv << ['Metric', 'Number of accounts', '% of total from start']
        csv << [
          'New Users Started IAL1 Verification',
          email_confirmation,
          format_as_percent(numerator: email_confirmation, denominator: email_confirmation),
        ]

        csv << [
          'New Users Completed IAL1 Password Setup',
          two_fa_setup_visited,
          format_as_percent(numerator: two_fa_setup_visited, denominator: email_confirmation),
        ]

        csv << [
          'New Users Completed IAL1 MFA',
          user_fully_registered,
          format_as_percent(numerator: user_fully_registered, denominator: email_confirmation),
        ]
        csv << [
          'New IAL1 Users Consented to Partner',
          sp_redirect_initiated_new_users,
          format_as_percent(
            numerator: sp_redirect_initiated_new_users,
            denominator: email_confirmation,
          ),
        ]
        csv << []
        csv << ['Total # of IAL1 Users', sp_redirect_initiated_all]
        csv << []
        csv << [
          'AAL2 Authentication Requests from Partner',
          oidc_auth_request,
          format_as_percent(numerator: oidc_auth_request, denominator: oidc_auth_request),
        ]
        csv << [
          'AAL2 Authenticated Requests',
          sp_redirect_initiated_after_oidc,
          format_as_percent(
            numerator: sp_redirect_initiated_after_oidc,
            denominator: oidc_auth_request,
          ),
        ]
      end
    end
    # rubocop:enable Metrics/BlockLength

    # event name => set(user ids)
    # @return Hash<String,Set<String>>
    def data
      @data ||= begin
        event_users = Hash.new do |h, uuid|
          h[uuid] = Set.new
        end

        fetch_results.each do |row|
          event_users[row['name']] << row['user_id']
        end

        event_users
      end
    end

    def email_confirmation
      data[Events::EMAIL_CONFIRMATION].count
    end

    def two_fa_setup_visited
      @two_fa_setup_visited ||=
        (data[Events::TWO_FA_SETUP_VISITED] & data[Events::EMAIL_CONFIRMATION]).count
    end

    def user_fully_registered
      @user_fully_registered ||=
        (data[Events::USER_FULLY_REGISTERED] & data[Events::EMAIL_CONFIRMATION]).count
    end

    def sp_redirect_initiated_new_users
      @sp_redirect_initiated_new_users ||=
        (data[Events::SP_REDIRECT] & data[Events::EMAIL_CONFIRMATION]).count
    end

    def sp_redirect_initiated_all
      data[Events::SP_REDIRECT].count
    end

    def oidc_auth_request
      data[Events::OIDC_AUTH_REQUEST].count
    end

    def sp_redirect_initiated_after_oidc
      @sp_redirect_initiated_after_oidc ||=
        (data[Events::SP_REDIRECT] & data[Events::OIDC_AUTH_REQUEST]).count
    end

    def fetch_results
      cloudwatch_client.fetch(query:, from: time_range.begin, to: time_range.end)
    end

    def query
      params = {
        issuer: quote(issuer),
        event_names: quote(Events.all_events),
        email_confirmation: quote(Events::EMAIL_CONFIRMATION),
      }

      format(<<~QUERY, params)
        fields
            name
          , properties.user_id AS user_id
        | filter properties.service_provider = %{issuer}
        | filter (name = %{email_confirmation} and properties.event_properties.success = 1)
                 or (name != %{email_confirmation})
        | filter name in %{event_names}
        | limit 10000
      QUERY
    end

    def cloudwatch_client
      @cloudwatch_client ||= Reporting::CloudwatchClient.new(
        num_threads: @threads,
        ensure_complete_logs: true,
        slice_interval: @slice,
        progress: progress?,
        logger: verbose? ? Logger.new(STDERR) : nil,
      )
    end

    # @return [String]
    def format_as_percent(numerator:, denominator:)
      (100 * numerator.to_f / denominator.to_f).round(2).to_s + '%'
    end
  end
end

# rubocop:disable Rails/Output
if __FILE__ == $PROGRAM_NAME
  options = Reporting::CommandLineOptions.new.parse!(ARGV)

  puts Reporting::AuthenticationReport.new(**options).to_csv
end
# rubocop:enable Rails/Output
