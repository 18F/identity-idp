# frozen_string_literal: true

module Proofing
  module Socure
    module IdPlus
      class Response
        # @param [Faraday::Response] http_response
        def initialize(http_response)
          @http_response = http_response
        end

        # @return [Hash<Symbol,Boolean>]
        def kyc_field_validations
          @kyc_field_validations ||= kyc('fieldValidations')
            .each_with_object({}) do |(field, valid), obj|
              obj[field.to_sym] = valid.round == 1
            end.freeze
        end

        # @return [Set<String>]
        def kyc_reason_codes
          @kyc_reason_codes ||= kyc('reasonCodes').to_set.freeze
        end

        def reference_id
          http_response.body['referenceId']
        end

        private

        attr_reader :http_response

        def kyc(*fields)
          kyc_object = http_response.body['kyc']
          raise 'No kyc section on response' unless kyc_object
          kyc_object.dig(*fields)
        end
      end
    end
  end
end
