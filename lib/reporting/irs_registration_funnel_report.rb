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
  class IrsRegistrationFunnelReport
    include Reporting::CloudwatchQueryQuoting

    attr_reader :issuers, :time_range

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

    # @param [Array<String>] issuers
    # @param [Range<Time>] time_range
    def initialize(
      issuers:,
      time_range:,
      verbose: false,
      progress: false,
      slice: 6.hours,
      threads: 1
    )
      @issuers = issuers
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

    def as_emailable_reports
      [
        Reporting::EmailableReport.new(
          title: 'Definitions',
          table: definitions_table,
          filename: 'definitions',
        ),
        Reporting::EmailableReport.new(
          title: 'Overview',
          table: overview_table,
          filename: 'overview',
        ),
        Reporting::EmailableReport.new(
          title: 'Registration Funnel Metrics',
          table: funnel_metrics_table,
          filename: 'funnel_metrics',
        ),
      ]
    end

    def definitions_table
      [
        ['Metric', 'Unit', 'Definition'],
        ['Registration Demand', 'Count',
         'The count of new users that started the registration process with Login.gov.'],
        ['Registration Failures', 'Count',
         'The count of new users who did not complete the registration process'],
        ['Registration Successes', 'Count',
         'The count of new users who completed the registration process sucessfully'],
        ['Registration Success Rate', 'Percentage',
         'The percentage of new users who completed registration process successfully'],
      ]
    end

    def overview_table
      [
        ['Report Timeframe', "#{time_range.begin} to #{time_range.end}"],
        # This needs to be Date.today so it works when run on the command line
        ['Report Generated', Time.zone.today.to_s],
        ['Issuer', issuers.present? ? issuers.join(', ') : 'All Issuers'],
      ]
    end

    def funnel_metrics_table
      [
        ['Metric', 'Number of accounts', '% of total from start'],
        [
          'Registration Demand',
          email_confirmation,
          format_as_percent(numerator: email_confirmation, denominator: email_confirmation),
        ],
        [
          'Registration Failures',
          users_failed_registration,
          format_as_percent(numerator: users_failed_registration, denominator: email_confirmation),
        ],
        [
          'Registration Successes',
          user_fully_registered,
          format_as_percent(numerator: user_fully_registered, denominator: email_confirmation),
        ],
        [
          'Registration Success Rate',
          sp_redirect_initiated_new_users,
          format_as_percent(
            numerator: sp_redirect_initiated_new_users,
            denominator: email_confirmation,
          ),
        ],
      ]
    end

    def format_as_percent(numerator:, denominator:)
      (100 * numerator.to_f / denominator.to_f).round(2).to_s + '%'
    end

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

    def fetch_results
      cloudwatch_client.fetch(query:, from: time_range.begin, to: time_range.end)
    end

    def query
      params = {
        issuers: quote(issuers),
        event_names: quote(Events.all_events),
        email_confirmation: quote(Events::EMAIL_CONFIRMATION),
      }

      format(<<~QUERY, params)
        fields
            name
          , properties.user_id AS user_id
        | filter properties.service_provider IN %{issuers}
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

    def email_confirmation
      data[Events::EMAIL_CONFIRMATION].count
    end

    def two_fa_setup_visited
      @two_fa_setup_visited ||=
        (data[Events::TWO_FA_SETUP_VISITED] & data[Events::EMAIL_CONFIRMATION]).count
    end

    def users_failed_registration
      @users_failed_registration ||=
        email_confirmation - user_fully_registered
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
  end
end
