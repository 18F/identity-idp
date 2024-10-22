# frozen_string_literal: true

module Proofing
  module Socure
    module ReasonCodes
      class Importer
        class ImportError < StandardError; end

        attr_reader :downloaded_reason_codes,
                    :added_reason_code_records,
                    :deactivated_reason_code_records

        def initialize
          @added_reason_code_records = []
          @deactivated_reason_code_records = []
        end

        def synchronize
          @downloaded_reason_codes = api_client.download_reason_codes

          if !downloaded_reason_codes.is_a?(Hash) || downloaded_reason_codes.empty?
            message = "Expected #{downloaded_reason_codes.inspect} to be a hash of reason codes"
            raise ImportError, message
          end

          create_or_update_downloaded_reason_codes
          deactivate_missing_reason_codes

          FormResponse.new(
            success: true,
            errors: nil,
            extra: {
              added_reason_codes: format_reason_code_records(added_reason_code_records),
              deactivated_reason_codes: format_reason_code_records(deactivated_reason_code_records),
            },
          )
        rescue ApiClient::ApiClientError,
               ImportError => e
          FormResponse.new(
            success: false,
            errors: nil,
            extra: { exception: e.inspect },
          )
        end

        def api_client
          @api_client ||= ApiClient.new
        end

        private

        def create_or_update_downloaded_reason_codes
          downloaded_reason_codes.each do |group, reason_codes|
            reason_codes.each do |code, description|
              reason_code = SocureReasonCode.find_or_initialize_by(code: code)
              added_reason_code_records.push(reason_code) unless reason_code.persisted?

              reason_code.group = group
              reason_code.description = description
              reason_code.added_at ||= Time.zone.now
              reason_code.deactivated_at = nil
              reason_code.save!
            end
          end
        end

        def deactivate_missing_reason_codes
          active_codes = downloaded_reason_codes.flat_map do |_group, reason_codes|
            reason_codes.keys
          end
          deactivated_at = Time.zone.now
          SocureReasonCode.active.where.not(code: active_codes).find_each do |reason_code|
            reason_code.update!(deactivated_at:)
            deactivated_reason_code_records.push(reason_code)
          end
        end

        def format_reason_code_records(socure_reason_codes)
          socure_reason_codes.map { |r| r.attributes.slice('code', 'group', 'description') }
        end
      end
    end
  end
end
