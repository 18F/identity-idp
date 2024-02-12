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
          next if c == :PHISHING_RESISTANT_METHODS

          if c == :PERSONAL_KEY
            'personal-key'
          else
            TwoFactorAuthenticatable::AuthMethod::const_get(c)
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
      slice: 3.hours,
      threads: 5
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

    # event name => set(user ids)
    # @return Hash<String,Set<String>>
    def data
      @data ||= begin
        event_users = Hash.new do |h, uuid|
          h[uuid] = Set.new
        end

        fetch_results.each do |row|
          event_users[row['mfa_method']] << row['user_id']
        end

        event_users
      end
    end

    def fetch_results
      @fetch_results ||= cloudwatch_client.fetch(query:, from: time_range.begin, to: time_range.end)
    end

    def query
      params = {
        issuers: quote(issuers),
        event_names: quote(Events.all_events),
      }

      format(<<~QUERY, params)
        fields properties.event_properties.multi_factor_auth_method as mfa_method
          , properties.user_id AS user_id
        | filter properties.service_provider IN %{issuers}
        | filter name in %{event_names} and not properties.event_properties.confirmation_for_add_phone and properties.event_properties.context != 'reauthentication'
        | filter properties.event_properties.success = '1'
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

    def overview_table
      [
        ['Report Timeframe', "#{time_range.begin} to #{time_range.end}"],
        # This needs to be Date.today so it works when run on the command line
        ['Report Generated', Date.today.to_s], # rubocop:disable Rails/Date
        ['Issuer', issuers.join(', ')],
      ]
    end

    def sms_auths
      data[TwoFactorAuthenticatable::AuthMethod::SMS].count
    end

    def webauthn_platform_auths
      data[TwoFactorAuthenticatable::AuthMethod::WEBAUTHN_PLATFORM].count
    end

    def webauthn_auths
      data[TwoFactorAuthenticatable::AuthMethod::WEBAUTHN].count
    end


    def totp_auths
      data[TwoFactorAuthenticatable::AuthMethod::TOTP].count
    end

    def backup_code_auths
      data[TwoFactorAuthenticatable::AuthMethod::BACKUP_CODE].count
    end

    def voice_auths
      data[TwoFactorAuthenticatable::AuthMethod::VOICE].count
    end

    def piv_cac_auths
      data[TwoFactorAuthenticatable::AuthMethod::PIV_CAC].count
    end

    def personal_key_auths
      # TwoFactorAuthenticatable::AuthMethod::PERSONAL_KEY has an underscore rather
      # than a hyphen
      data['personal-key'].count
    end

    def phishing_resistant_total
      webauthn_auths + webauthn_platform_auths + piv_cac_auths
    end

    def multi_factor_auth_table
      [
        ['Multi Factor Authentication (MFA) method', 'Number of successful sign-ins'],
        [
          'SMS',
          sms_auths,
        ],
        [
          'Voice',
          voice_auths,
        ],
        [
          'Security key',
          webauthn_auths,
        ],
        [
          'Face or touch unlock',
          webauthn_platform_auths
        ],
        [
          'PIV/CAC',
          piv_cac_auths
        ],
        [
          'Authentication app',
          totp_auths,
        ],
        [
          'Backup codes',
          backup_code_auths,
        ],

        [
          'Personal key',
          personal_key_auths
        ],
        [
          'Total number of phishing resistant methods',
          phishing_resistant_total
        ]
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
