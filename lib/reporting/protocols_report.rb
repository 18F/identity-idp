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
    SAML_AUTH_REQUEST_EVENT = 'SAML Auth Request'
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
        deprecated_parameters_table,
        feature_use_table,
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
        Reporting::EmailableReport.new(
          title: 'Deprecated Parameter Usage',
          table: deprecated_parameters_table,
        ),
        Reporting::EmailableReport.new(
          title: 'Feature Usage',
          table: feature_use_table,
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

    def overview_table
      [
        ['Report Timeframe', "#{time_range.begin} to #{time_range.end}"],
        # This needs to be Date.today so it works when run on the command line
        ['Report Generated', Date.today.to_s], # rubocop:disable Rails/Date
      ]
    end

    def protocols_table
      [
        ['Authentication Protocol', '% of requests', 'Total requests', 'Count of issuers'],
        [
          'SAML',
          to_percent(saml_count, saml_count + oidc_count),
          saml_count,
          saml_issuer_count,
        ],
        [
          'OIDC',
          to_percent(oidc_count, saml_count + oidc_count),
          oidc_count,
          oidc_issuer_count,
        ],
      ]
    end

    def saml_signature_issues_table
      [
        ['Issue', 'Count of issuers', 'List of issuers'],
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

    def deprecated_parameters_table
      [
        [
          'Deprecated Parameter',
          'Count of issuers',
          'List of issuers',
        ],
        [
          'LOA',
          loa_issuers_data.length,
          loa_issuers_data.join(', '),
        ],
        [
          'AAL3',
          aal3_issuers_data.length,
          aal3_issuers_data.join(', '),
        ],
        [
          'id_token_hint',
          id_token_hint_data.length,
          id_token_hint_data.join(', '),
        ],
        [
          'No openid in scope',
          no_openid_scope_data.length,
          no_openid_scope_data.join(', '),
        ],
      ]
    end

    def feature_use_table
      [
        [
          'Feature',
          'Count of issuers',
          'List of issuers',
        ],
        [
          'IdV with Facial Match',
          facial_match_data.length,
          facial_match_data.join(', '),
        ],
      ]
    end

    def saml_count
      protocol_data[:saml][:request_count]
    end

    def oidc_count
      protocol_data[:oidc][:request_count]
    end

    def saml_issuer_count
      protocol_data[:saml][:issuer_count]
    end

    def oidc_issuer_count
      protocol_data[:oidc][:issuer_count]
    end

    def loa_issuers_data
      @loa_issuers_data ||= fetch_uniq_issuers(
        query: loa_issuers_query,
      )
    end

    def no_openid_scope_data
      @no_openid_scope_data ||= fetch_uniq_issuers(
        query: no_openid_scope_query,
      )
    end

    def aal3_issuers_data
      @aal3_issuers_data ||= fetch_uniq_issuers(
        query: aal3_issuers_query,
      )
    end

    def facial_match_data
      @facial_match_data ||= fetch_uniq_issuers(
        query: facial_match_issuers_query,
      )
    end

    def id_token_hint_data
      @id_token_hint_data ||= fetch_uniq_issuers(
        query: id_token_hint_query,
      )
    end

    def protocol_data
      @protocol_data ||= begin
        results = cloudwatch_client.fetch(
          query: protocol_query,
          from: time_range.begin,
          to: time_range.end,
        )
        {
          saml: {
            request_count: results
              .select { |slice| slice['protocol'] == SAML_AUTH_EVENT }
              .map { |slice| slice['request_count'].to_i }
              .sum,
            issuer_count: by_uniq_issuers(
              results
                .select { |slice| slice['protocol'] == SAML_AUTH_EVENT },
            ).count,
          },
          oidc: {
            request_count: results
              .select { |slice| slice['protocol'] == OIDC_AUTH_EVENT }
              .map { |slice| slice['request_count'].to_i }
              .sum,
            issuer_count: by_uniq_issuers(
              results.select { |slice| slice['protocol'] == OIDC_AUTH_EVENT },
            ).count,
          },
        }
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
          unsigned: by_uniq_issuers(
            results.select { |slice| slice['unsigned_count'].to_i > 0 },
          ),
          invalid_signature: results
            .select { |slice| slice['invalid_signature_count'].to_i > 0 }
            .map { |slice| slice['issuer'] }
            .uniq,
        }
      end
    end

    def aal3_issuers_query
      params = {
        events: quote([SAML_AUTH_EVENT, OIDC_AUTH_EVENT]),
      }

      format(<<~QUERY, params)
        fields
          coalesce(properties.event_properties.service_provider, properties.event_properties.client_id) as issuer,
          properties.event_properties.acr_values as acr
        | parse @message '"authn_context":[*]' as authn
        | filter
          name IN %{events}
          AND (authn like /aal\\/3/ or acr like /aal\\/3/)
          AND properties.event_properties.success = 1
        | display issuer
        | sort issuer
        | dedup issuer
      QUERY
    end

    def facial_match_issuers_query
      params = {
        events: quote([SAML_AUTH_EVENT, OIDC_AUTH_EVENT]),
      }
      # OIDC_AUTH_EVENT and SAML_AUTH_EVENTs are fired before the initiating
      # session is stored.
      # We are omitting those events to prevent false positives
      format(<<~QUERY, params)
        fields
          coalesce(properties.event_properties.service_provider,
          properties.event_properties.client_id,
          properties.service_provider) as issuer
        | filter name NOT IN %{events}
        | filter properties.sp_request.facial_match
        | display issuer
        | sort issuer
        | dedup issuer
      QUERY
    end

    def id_token_hint_query
      format(<<~QUERY)
        fields @timestamp,
          coalesce(properties.event_properties.id_token_hint_parameter_present, 0) as id_token_hint,
          coalesce(properties.event_properties.client_id, properties.service_provider) as issuer
        | filter ispresent(id_token_hint) and id_token_hint > 0 and name = 'OIDC Logout Requested'
        | display issuer
        | sort issuer
        | dedup issuer
      QUERY
    end

    def no_openid_scope_query
      params = {
        event: quote(OIDC_AUTH_EVENT),
      }

      format(<<~QUERY, params)
        fields @timestamp,
          coalesce(properties.event_properties.client_id, properties.service_provider) as issuer
        | filter name = %{event}
          AND properties.event_properties.success = 1
          AND properties.event_properties.scope NOT LIKE 'openid'
        | display issuer
        | sort issuer
        | dedup issuer
      QUERY
    end

    def loa_issuers_query
      params = {
        event: quote([SAML_AUTH_EVENT, OIDC_AUTH_EVENT]),
      }

      format(<<~QUERY, params)
        fields
          coalesce(properties.event_properties.service_provider, properties.event_properties.client_id) as issuer,
          properties.event_properties.acr_values as acr
        | parse @message '"authn_context":[*]' as authn
        | filter
          name IN %{event}
          AND (authn like /ns\\/assurance\\/loa/ OR acr like /ns\\/assurance\\/loa/)
          AND properties.event_properties.success= 1
        | display issuer
        | sort issuer
        | dedup issuer
      QUERY
    end

    def protocol_query
      params = {
        event: quote([SAML_AUTH_EVENT, OIDC_AUTH_EVENT]),
      }

      format(<<~QUERY, params)
        fields
          name AS protocol,
          coalesce(properties.event_properties.service_provider, properties.event_properties.client_id) as issuer
        | filter name IN %{event} AND properties.event_properties.success= 1
        | stats
            count(*) AS request_count
          BY
          protocol, issuer
      QUERY
    end

    def saml_signature_query
      params = {
        events: quote([SAML_AUTH_REQUEST_EVENT]),
      }

      format(<<~QUERY, params)
        fields
          properties.event_properties.service_provider AS issuer,
          properties.event_properties.request_signed = 1 AS signed,
          properties.event_properties.request_signed != 1 AS not_signed,
          isempty(properties.event_properties.matching_cert_serial) AND signed AS invalid_signature
        | filter name IN %{events}
        | stats
          sum(not_signed) AS unsigned_count,
          sum(invalid_signature) AS invalid_signature_count
          BY
          issuer
        | sort
          issuer
      QUERY
    end

    def fetch_uniq_issuers(query:)
      by_uniq_issuers(
        cloudwatch_client.fetch(
          query:,
          from: time_range.begin,
          to: time_range.end,
        ),
      )
    end

    def by_uniq_issuers(data)
      data.map { |slice| slice['issuer'] }.uniq
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

    def to_percent(numerator, denominator)
      (100.0 * numerator / denominator).round(2)
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  options = Reporting::CommandLineOptions.new.parse!(ARGV, require_issuer: false)

  Reporting::ProtocolsReport.new(**options).to_csvs.each do |csv|
    puts csv
  end
end
