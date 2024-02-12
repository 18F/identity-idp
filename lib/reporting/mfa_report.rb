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
  class MfaReport
    include Reporting::CloudwatchQueryQuoting

    attr_reader :issuers, :time_range

    module Events
      MULTI_FACTOR_AUTH = 'Multi-Factor Authentication'

      def self.all_events
        constants.map { |c| const_get(c) }
      end
    end

    module Methods
      def self.all_methods
        TwoFactorAuthenticatable::AuthMethod.constants.map do |c|
          next if c == :PHISHING_RESISTANT_METHODS || c == :REMEMBER_DEVICE

          if c == :PERSONAL_KEY
            # The AuthMethod constant defines this as `personal_key`
            # but in the events it is `personal-key`
            'personal-key'
          else
            TwoFactorAuthenticatable::AuthMethod.const_get(c)
          end
        end.compact
      end
    end

    # @param [Array<String>] issuers
    # @param [Range<Time>] time_range
    def initialize(
      issuers:,
      time_range:,
      verbose: false,
      progress: false,
      slice: 1.day,
      threads: 10
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

    def as_tables
      [
        overview_table,
        multi_factor_auth_table,
      ]
    end

    def as_emailable_reports
      [
        Reporting::EmailableReport.new(
          title: 'Overview',
          table: overview_table,
        ),
        Reporting::EmailableReport.new(
          title: 'Multi Factor Authentication Metrics',
          table: multi_factor_auth_table,
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

    # @return Array<Hash>
    def data
      @data ||= begin
        fetch_results
      end
    end

    def fetch_results
      cloudwatch_client.fetch(query:, from: time_range.begin, to: time_range.end)
    end

    def query
      params = {
        issuers: quote(issuers),
        event_names: quote(Events.all_events),
        fields:,
        stats:,
      }

      format(<<~QUERY, params)
        fields %{fields}
        | filter properties.service_provider IN %{issuers}
        | filter name in %{event_names} and not properties.event_properties.confirmation_for_add_phone and properties.event_properties.context != 'reauthentication'
        | filter properties.event_properties.success = '1'
        | stats %{stats}
      QUERY
    end

    def fields
      Methods.all_methods.map do |method|
        # Cloudwatch doesn't like the hyphen in personal-key
        no_hypen_method = method.tr('-', '_')
        'properties.event_properties.multi_factor_auth_method = ' +
          "#{method}' as #{no_hypen_method}"
      end.join(', ')
    end

    def stats
      Methods.all_methods.map do |method|
        m = method.tr('-', '_')
        "sum(#{m}) as `#{m + '_total'}`"
      end.join(', ')
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

    def overview_table
      [
        ['Report Timeframe', "#{time_range.begin} to #{time_range.end}"],
        # This needs to be Date.today so it works when run on the command line
        ['Report Generated', Date.today.to_s], # rubocop:disable Rails/Date
        ['Issuer', issuers.join(', ')],
      ]
    end

    def totals(key)
      data.inject(0) { |sum, slice| slice[key].to_i + sum }
    end

    def multi_factor_auth_table
      [
        ['Multi Factor Authentication (MFA) method', 'Number of successful sign-ins'],
        [
          'SMS',
          totals('sms_total'),
        ],
        [
          'Voice',
          totals('voice_total'),
        ],
        [
          'Security key',
          totals('webauthn_total'),
        ],
        [
          'Face or touch unlock',
          totals('webauthn_platform_total'),
        ],
        [
          'PIV/CAC',
          totals('piv_cac_total'),
        ],
        [
          'Authentication app',
          totals('totp_total'),
        ],
        [
          'Backup codes',
          totals('backup_code_total'),
        ],
        [
          'Personal key',
          totals('personal_key_total'),
        ],
        [
          'Total number of phishing resistant methods',
          totals('webauthn_total') + totals('webauthn_platform_total') + totals('piv_cac_total'),
        ],
      ]
    end
  end
end

# rubocop:disable Rails/Output
if __FILE__ == $PROGRAM_NAME
  options = Reporting::CommandLineOptions.new.parse!(ARGV)

  Reporting::MfaReport.new(**options).to_csvs.each do |csv|
    puts csv
  end
end
# rubocop:enable Rails/Output
