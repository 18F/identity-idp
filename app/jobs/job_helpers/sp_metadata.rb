# frozen_string_literal: true

module JobHelpers
  module ServiceProviderMetadata
    # Returns detailed service provider information for a given issuer string
    # @param issuer_string [String] the issuer string to look up
    # @return [Hash, nil] service provider metadata or nil if not found
    def get_service_provider_info(issuer_string)
      @sp_metadata_mapping ||= build_service_provider_metadata_mapping
      @sp_metadata_mapping[issuer_string]
    end

    # Returns detailed service provider information for multiple issuer strings
    # @param issuer_strings [Array<String>] array of issuer strings to look up
    # @return [Hash] mapping of issuer strings to their metadata
    def get_service_provider_info_batch(issuer_strings)
      @sp_metadata_mapping ||= build_service_provider_metadata_mapping
      issuer_strings.index_with { |issuer| @sp_metadata_mapping[issuer] }.compact
    end

    # Clears the cached metadata mapping (useful for tests or when data changes)
    def clear_service_provider_metadata_cache
      @sp_metadata_mapping = nil
    end

    private

    def build_service_provider_metadata_mapping
      raw_data = fetch_service_provider_metadata_data
      format_service_provider_metadata(raw_data)
    end

    def fetch_service_provider_metadata_data
      sql = <<~SQL
        SELECT 
          sp.issuer,
          sp.id,
          sp.friendly_name,
          sp.agency_id,
          sp.active,
          agencies.name as agency_name,
          agencies.abbreviation as agency_abbreviation
        FROM service_providers sp
        LEFT JOIN agencies ON sp.agency_id = agencies.id
        WHERE sp.issuer IS NOT NULL 
          AND TRIM(sp.issuer) <> ''
        ORDER BY sp.issuer;
      SQL

      transaction_with_timeout do
        ActiveRecord::Base.connection.execute(sql)
      end.to_a
    rescue StandardError => e
      Rails.logger.error "Failed to fetch service provider metadata: #{e.message}"
      raise e
    end

    def format_service_provider_metadata(raw_data)
      if raw_data.empty?
        Rails.logger.warn 'No service providers found in service_providers table'
        return {}
      end

      mapping = {}
      raw_data.each do |row|
        issuer = row['issuer']

        if mapping.key?(issuer)
          Rails.logger.error "Duplicate issuer found in service_providers: #{issuer}. "\
                             "Keeping first record."
          next
        end

        mapping[issuer] = {
          id: row['id'],
          friendly_name: row['friendly_name'],
          active: row['active'],
          agency_id: row['agency_id'],
          agency_name: row['agency_name'],
          agency_abbreviation: row['agency_abbreviation'],
        }
      end

      mapping
    end
  end
end
