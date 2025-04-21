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
  class AccountResetReport
    include Reporting::CloudwatchQueryQuoting

    attr_reader :time_range

    module Events
      EMAIL_PASSWORD_AUTH = 'Email and Password Authenication'
      ACCOUNT_RESET_DELETE = 'Account Reset: delete'

      def self.all_events
        constants.map { |c| const_get(c) }
      end
    end

    # @param [Range<Time>] time_range
    def initialize(
      time_range:,
      verbose: false,
      progress: false,
      slice: 3.hours,
      threads: 5
    )
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

    def as_tables
      [
        account_reset_table
      ]
    end

    def as_emailable_reports
      [
        Reporting::EmailableReport.new(
          title: 'Account Reset Rate',
          table: account_reset_table,
        ),
      ]
    end
    
    def to_csvs
      as_tables.map do |table|
        CSV.generate do |csv|
          table.each do |row|
            csv << row
          end
        end
      end
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

    def account_reset_delete
      data[Events::ACCOUNT_RESET_DELETE].count
    end

    def email_password_auth
      data[Events::EMAIL_PASSWORD_AUTH].count
    end

    def fetch_results
      cloudwatch_client.fetch(query:, from: time_range.begin, to: time_range.end)
    end

    def query
      params = {
        event_names: quote(Events.all_events),
        email_password_auth: quote(Events::EMAIL_PASSWORD_AUTH),
      }

      format(<<~QUERY, params)
        fields
            name
          , properties.user_id AS user_id
        | filter (name = %{email_password_auth} and properties.event_properties.success = 0)
                 or (name != %{email_password_auth})
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

    def account_reset_table
      [
        ['Accounts Reset', 'Authentication Attempts', 'Account Reset Rate'],
        [
          account_reset_delete,
          email_password_auth,
          format_as_percent(numerator: account_reset_delete, denominator: email_password_auth),
        ],
      ]
    end

    # @return [String]
    def format_as_percent(numerator:, denominator:)
      (100 * numerator.to_f / denominator.to_f).round(2).to_s + '%'
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  options = Reporting::CommandLineOptions.new.parse!(ARGV)

  Reporting::AccountResetReport.new(**options).to_csvs.each do |csv|
    puts csv
  end
end
