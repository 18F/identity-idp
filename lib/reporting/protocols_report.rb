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
  class ProtocolsReport
    include Reporting::CloudwatchQueryQuoting

    attr_reader :time_range

    SAML_AUTH_EVENT = 'SAML Auth'
    OIDC_AUTH_EVENT = 'OpenID Connect: authorization request'

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
        protocols_table,
        saml_signature_issues_table,
      ]
    end

    def as_emailable_reports
      [
        Reporting::EmailableReport.new(
          title: 'Overview',
          table: overview_table,
        ),
        Reporting::EmailableReport.new(
          title: 'State of Authentication',
          table: protocols_table,
        ),
        Reporting::EmailableReport.new(
          title: 'SAML Signature Issues',
          table: saml_signature_issues_table,
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

    def protocol_data
      @protocol_data ||= begin
        protocol_counts = Hash.new(0)
        cloudwatch_client.fetch(
          query: protocol_query,
          from: time_range.begin,
          to: time_range.end,
        ).each do |row|
          protocol_counts[row['protocol']] += row['request_count'].to_i
        end
        protocol_counts
      end
    end

    def saml_signature_data
      @saml_signature_data ||= begin
        results = cloudwatch_client.fetch(
          query: saml_signature_query,
          from: time_range.begin,
          to: time_range.end,
        )
        {
          unsigned: results.
            select { |slice| slice['unsigned_count'].to_i > 0 }.
            map { |slice| slice['issuer'] }.
            uniq,
          invalid_signature: results.
            select { |slice| slice['invalid_signature_count'].to_i > 0 }.
            map { |slice| slice['issuer'] }.
            uniq,
        }
      end
    end

    def protocol_query
      params = {
        event: quote([SAML_AUTH_EVENT, OIDC_AUTH_EVENT]),
      }

      format(<<~QUERY, params)
        fields
          name AS protocol
        | filter name IN %{event}
        | stats
          count(*) AS request_count
          BY
          protocol
      QUERY
    end

    def saml_signature_query
      params = {
        event: quote([SAML_AUTH_EVENT]),
      }

      format(<<~QUERY, params)
        fields
          properties.event_properties.service_provider AS issuer,
          properties.event_properties.request_signed = 1 AS signed,
          properties.event_properties.request_signed != 1 AS not_signed,
          isempty(properties.event_properties.matching_cert_serial) AND signed AS invalid_signature
        | filter name IN %{event}
          AND properties.event_properties.success = 1
        | stats
          sum(not_signed) AS unsigned_count,
          sum(invalid_signature) AS invalid_signature_count
          BY
          issuer
        | sort
          issuer
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
      ]
    end

    def saml_count
      protocol_data[SAML_AUTH_EVENT]
    end

    def oidc_count
      protocol_data[OIDC_AUTH_EVENT]
    end

    def protocols_table
      [
        ['Authentication Protocol', '% of attempts', 'Total number'],
        [
          'SAML',
          to_percent(saml_count, saml_count + oidc_count),
          saml_count,
        ],
        [
          'OIDC',
          to_percent(oidc_count, saml_count + oidc_count),
          oidc_count,
        ],
      ]
    end

    def saml_signature_issues_table
      [
        ['Issue', 'Count of integrations with the issue', 'List of issuers with the issue'],
        [
          'Not signing SAML authentication requests',
          saml_signature_data[:unsigned].length,
          saml_signature_data[:unsigned].join(', '),
        ],
        [
          'Incorrectly signing SAML authentication requests',
          saml_signature_data[:invalid_signature].length,
          saml_signature_data[:invalid_signature].join(', '),
        ],
      ]
    end

    def to_percent(numerator, denominator)
      (100.0 * numerator / denominator).round(2)
    end
  end
end

# rubocop:disable Rails/Output
if __FILE__ == $PROGRAM_NAME
  options = Reporting::CommandLineOptions.new.parse!(ARGV, require_issuer: false)

  Reporting::ProtocolsReport.new(**options).to_csvs.each do |csv|
    puts csv
  end
end
# rubocop:enable Rails/Output
