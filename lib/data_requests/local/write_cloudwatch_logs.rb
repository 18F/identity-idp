# frozen_string_literal: true

require 'csv'

module DataRequests
  module Local
    class WriteCloudwatchLogs
      HEADERS = %w[
        uuid
        timestamp
        event_name
        success
        multi_factor_auth_method
        multi_factor_id
        service_provider
        ip_address
        user_agent
      ].freeze

      attr_reader :cloudwatch_results, :requesting_issuer_uuid, :csv

      def initialize(cloudwatch_results:, requesting_issuer_uuid:, csv:, include_header: false)
        @cloudwatch_results = cloudwatch_results
        @requesting_issuer_uuid = requesting_issuer_uuid
        @csv = csv
        @include_header = include_header
      end

      def include_header?
        !!@include_header
      end

      def call
        csv << HEADERS if include_header?

        cloudwatch_results.each do |row|
          csv << build_row(row)
        end
      end

      private

      def build_row(row)
        data = JSON.parse(row.message)

        timestamp = data.dig('time')
        event_name = data.dig('name')
        success = data.dig('properties', 'event_properties', 'success')
        multi_factor_auth_method = data.dig(
          'properties', 'event_properties', 'multi_factor_auth_method'
        )

        mfa_key = case multi_factor_auth_method
        when 'sms', 'voice'
          'phone_configuration_id'
        when 'piv_cac'
          'piv_cac_configuration_id'
        when 'webauthn'
          'webauthn_configuration_id'
        when 'totp'
          'auth_app_configuration_id'
        end

        row_id = data.dig('properties', 'event_properties', mfa_key)
        multi_factor_id = row_id && "#{mfa_key}:#{row_id}"
        service_provider = data.dig('properties', 'service_provider')
        ip_address = data.dig('properties', 'user_ip')
        user_agent = data.dig('properties', 'user_agent')

        [
          requesting_issuer_uuid,
          timestamp,
          event_name,
          success,
          multi_factor_auth_method,
          multi_factor_id,
          service_provider,
          ip_address,
          user_agent,
        ]
      end
    end
  end
end
