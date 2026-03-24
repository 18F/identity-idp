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
    EVENT = 'Multi-Factor Authentication'

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
        event: quote(EVENT),
      }

      format(<<~QUERY, params)
        fields properties.event_properties.multi_factor_auth_method = 'backup_code' as backup_code,
          properties.event_properties.multi_factor_auth_method = 'voice' as voice,
          properties.event_properties.multi_factor_auth_method = 'webauthn' as webauthn,
          properties.event_properties.multi_factor_auth_method = 'webauthn_platform' as webauthn_platform,
          properties.event_properties.multi_factor_auth_method = 'personal-key' as personal_key,
          properties.event_properties.multi_factor_auth_method = 'totp' as totp,
          properties.event_properties.multi_factor_auth_method = 'piv_cac' as piv_cac,
          properties.event_properties.multi_factor_auth_method = 'sms' as sms
        | filter properties.service_provider IN %{issuers}
        | filter name = %{event}
          AND NOT properties.event_properties.confirmation_for_add_phone
          AND properties.event_properties.context != 'reauthentication'
        | filter properties.event_properties.success = '1'
        | stats sum(backup_code) as `backup_code_total`,
          sum(voice) as `voice_total`,
          sum(webauthn) as `webauthn_total`,
          sum(webauthn_platform) as `webauthn_platform_total`,
          sum(personal_key) as `personal_key_total`,
          sum(totp) as `totp_total`,
          sum(piv_cac) as `piv_cac_total`,
          sum(sms) as `sms_total`
      QUERY
    end

    def cloudwatch_client
      @cloudwatch_client ||= Reporting::CloudwatchClient.new(
        num_threads: @threads,
        ensure_complete_logs: false,
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
      data.reduce(0) { |sum, slice| slice[key].to_i + sum }
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

if __FILE__ == $PROGRAM_NAME
  options = Reporting::CommandLineOptions.new.parse!(ARGV)

  Reporting::MfaReport.new(**options).to_csvs.each do |csv|
    puts csv
  end
end
